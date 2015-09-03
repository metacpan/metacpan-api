package MetaCPAN::Script::Latest;

use strict;
use warnings;

use Log::Contextual qw( :log );
use Moose;
use MooseX::Aliases;
use Parse::CPAN::Packages::Fast;
use Regexp::Common qw(time);
use Time::Local;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has dry_run => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has distribution => (
    is  => 'ro',
    isa => 'Str',
);

has packages => (
    is         => 'ro',
    lazy_build => 1,
    traits     => ['NoGetopt'],
);

sub _build_packages {
    return Parse::CPAN::Packages::Fast->new(
        shift->cpan->file(qw(modules 02packages.details.txt.gz))->stringify );
}

sub run {
    my $self    = shift;
    my $modules = $self->index->type('file');

    if ( $self->dry_run ) {
        log_info {'Dry run: updates will not be written to ES'};
    }

    my $p = $self->packages;
    $self->index->refresh;

    # If a distribution name is passed get all the package names
    # from 02packages that match that distribution so we can limit
    # the ES query to just those modules.
    my @filter;
    if ( my $distribution = $self->distribution ) {
        foreach my $package ( $p->packages ) {
            my $dist = $p->package($package)->distribution->dist;
            push( @filter, $package )
                if ( $dist && $dist eq $distribution );
        }
        log_info { "$distribution consists of " . @filter . ' modules' };
    }

    return if ( !@filter && $self->distribution );

    my $scroll = $modules->filter(
        {
            and => [
                @filter
                ? {
                    or => [
                        map { { term => { 'file.module.name' => $_ } } }
                            @filter
                    ]
                    }
                : (),
                { exists => { field                 => 'file.module.name' } },
                { term   => { 'file.module.indexed' => \1 } },
                { term   => { 'file.maturity'       => 'released' } },
                { not => { filter => { term => { status => 'backpan' } } } },
                {
                    not => {
                        filter =>
                            { term => { 'file.distribution' => 'perl' } }
                    }
                },
            ]
        }
        )->fields(
        [
            'file.module.name', 'file.author',
            'file.release',     'file.distribution',
            'file.date',        'file.status',
        ]
        )->size(10000)->raw->scroll('1h');

    my ( %downgrade, %upgrade );
    log_debug { 'Found ' . $scroll->total . ' modules' };

    my $i = 0;

    my @modules_to_purge;

    # For each file...
    while ( my $file = $scroll->next ) {
        $i++;
        log_debug { "$i of " . $scroll->total } unless ( $i % 1000 );
        my $data = $file->{fields};
        my @modules
            = ref $data->{'module.name'}
            ? @{ $data->{'module.name'} }
            : $data->{'module.name'};

       # Convert module name into Parse::CPAN::Packages::Fast::Package object.
        @modules = grep {defined} map {
            eval { $p->package($_) }
        } @modules;

        push @modules_to_purge, @modules;

        # For each of the packages in this file...
        foreach my $module (@modules) {

           # Get P:C:P:F:Distribution (CPAN::DistnameInfo) object for package.
            my $dist = $module->distribution;

            # If 02packages has the same author/release for this package...

            # NOTE: CPAN::DistnameInfo doesn't parse some weird uploads
            # (like /\.pm\.gz$/) so distvname might not be present.
            # I assume cpanid always will be.
            if (   defined( $dist->distvname )
                && $dist->distvname eq $data->{release}
                && $dist->cpanid eq $data->{author} )
            {
                my $upgrade = $upgrade{ $data->{distribution} };

                # If multiple versions of a dist appear in 02packages
                # only mark the most recent upload as latest.
                next
                    if ( $upgrade
                    && $self->compare_dates( $upgrade->{date}, $data->{date} )
                    );
                $upgrade{ $data->{distribution} } = $data;
            }
            elsif ( $data->{status} eq 'latest' ) {
                $downgrade{ $data->{release} } = $data;
            }
        }
    }

    while ( my ( $dist, $data ) = each %upgrade ) {

        # Don't reindex if already marked as latest.
        # This just means that it hasn't changed (query includes 'latest').
        next if ( $data->{status} eq 'latest' );

        $self->reindex( $data, 'latest' );
    }

    while ( my ( $release, $data ) = each %downgrade ) {

        # Don't downgrade if this release version is also marked as latest.
        # This could happen if a module is moved to a new dist
        # but the old dist remains (with other packages).
        # This could also include bug fixes in our indexer, PAUSE, etc.
        next
            if ( $upgrade{ $data->{distribution} }
            && $upgrade{ $data->{distribution} }->{release} eq
            $data->{release} );

        $self->reindex( $data, 'cpan' );
    }
    $self->index->refresh;

    # We just want the CPAN::DistnameInfo
    my @module_to_purge_dists = map { $_->distribution } @modules_to_purge;

    # Call Fastly to purge
    $self->cdn_purge_cpan_distnameinfos(
        {
            keys => \@module_to_purge_dists
        }
    );

}

# Update the status for the release and all the files.
sub reindex {
    my ( $self, $source, $status ) = @_;
    my $es = $self->es;

    # Update the status on the release.
    my $release = $self->index->type('release')->get(
        {
            author => $source->{author},
            name   => $source->{release},
        }
    );

    $release->status($status);
    log_info {
        $status eq 'latest' ? 'Upgrading ' : 'Downgrading ',
            'release ', $release->name || q[];
    };
    $release->put unless ( $self->dry_run );

    # Get all the files for the release.
    my $scroll = $es->scrolled_search(
        {
            index       => $self->index->name,
            type        => 'file',
            scroll      => '5m',
            size        => 1000,
            search_type => 'scan',
            query       => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            {
                                term =>
                                    { 'file.release' => $source->{release} }
                            },
                            {
                                term => { 'file.author' => $source->{author} }
                            }
                        ]
                    }
                }
            }
        }
    );

    my @bulk;
    while ( my $row = $scroll->next ) {
        my $source = $row->{_source};
        log_trace {
            $status eq 'latest' ? 'Upgrading ' : 'Downgrading ',
                'file ', $source->{name} || q[];
        };

        # Use bulk update to overwrite the status for X files at a time.
        push(
            @bulk,
            {
                index => {
                    index => $self->index->name,
                    type  => 'file',
                    id    => $row->{_id},
                    data  => { %$source, status => $status }
                }
            }
        ) unless ( $self->dry_run );
        if ( @bulk > 100 ) {
            $self->es->bulk( \@bulk );
            @bulk = ();
        }
    }
    $self->es->bulk( \@bulk ) if (@bulk);
}

sub compare_dates {
    my ( $self, $d1, $d2 ) = @_;
    for ( $d1, $d2 ) {
        if ( $_ =~ /$RE{time}{iso}{-keep}/ ) {
            $_ = timelocal( $7, $6, $5, $4, $3 - 1, $2 );
        }
    }
    return $d1 > $d2;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan latest

 # bin/metacpan latest --dry_run

=head1 DESCRIPTION

After importing releases from cpan, this script will set the status
to latest on the most recent release, its files and dependencies.
It also makes sure that there is only one latest release per distribution.
