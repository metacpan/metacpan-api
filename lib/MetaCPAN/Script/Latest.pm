package MetaCPAN::Script::Latest;

use Moose;
use MooseX::Aliases;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Parse::CPAN::Packages::Fast;
use Time::Local;
use Regexp::Common qw(time);

has dry_run => ( is => 'ro', isa => 'Bool', default => 0 );
has distribution => ( is => 'ro', isa => 'Str' );
has packages => ( is => 'ro', lazy_build => 1, traits => ['NoGetopt'], );

sub _build_packages {
    return Parse::CPAN::Packages::Fast->new(
        shift->cpan->file(qw(modules 02packages.details.txt.gz))->stringify );
}

sub run {
    my $self    = shift;
    my $modules = $self->index->type('file');
    log_info {"Dry run: updates will not be written to ES"}
    if ( $self->dry_run );
    my $p = $self->packages;
    $self->index->refresh;

    my @filter;
    if ( my $distribution = $self->distribution ) {
        foreach my $package ( $p->packages ) {
            my $dist = $p->package($package)->distribution->dist;
            push( @filter, $package )
                if ( $dist && $dist eq $distribution );
        }
        log_info { "$distribution consists of " . @filter . " modules" };
    }

    return if ( !@filter && $self->distribution );
    my $scroll = $modules->filter(
        {   and => [
                @filter
                ? { or => [
                        map { { term => { 'file.module.name' => $_ } } }
                            @filter
                    ]
                    }
                : (),
                { exists => { field                 => 'file.module.name' } },
                { term   => { 'file.module.indexed' => \1 } },
                { term   => { 'file.maturity'       => 'released' } },
                { not => { filter => { term => { status => 'backpan' } } } },
                {   not => {
                        filter =>
                            { term => { 'file.distribution' => 'perl' } }
                    }
                },
            ]
        }
        )->fields(
        [   'file.module.name', 'file.author',
            'file.release',     'file.distribution',
            'file.date',        'file.status',
        ]
        )->size(10000)->raw->scroll('1h');

    my ( %downgrade, %upgrade );
    log_debug { "Found " . $scroll->total . " modules" };

    my $i = 0;
    while ( my $file = $scroll->next ) {
        $i++;
        log_debug { "$i of " . $scroll->total } unless ( $i % 1000 );
        my $data = $file->{fields};
        my @modules
            = ref $data->{'module.name'}
            ? @{ $data->{'module.name'} }
            : $data->{'module.name'};
        @modules = grep {defined} map {
            eval { $p->package($_) }
        } @modules;
        foreach my $module (@modules) {
            my $dist = $module->distribution;
            if (   $dist->distvname eq $data->{release}
                && $dist->cpanid eq $data->{author} )
            {
                my $upgrade = $upgrade{ $data->{distribution} };
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
        next if ( $data->{status} eq 'latest' );
        $self->reindex( $data, 'latest' );
    }
    while ( my ( $release, $data ) = each %downgrade ) {
        next
            if ( $upgrade{ $data->{distribution} }
            && $upgrade{ $data->{distribution} }->{release} eq
            $data->{release} );
        $self->reindex( $data, 'cpan' );
    }
    $self->index->refresh;
}

sub reindex {
    my ( $self, $source, $status ) = @_;
    my $es = $self->es;

    my $release = $self->index->type('release')->get(
        {   author => $source->{author},
            name   => $source->{release},
        }
    );

    $release->status($status);
    log_info {
        $status eq 'latest' ? "Upgrading " : "Downgrading ",
            "release ", $release->name || '';
    };
    $release->put unless ( $self->dry_run );

    my $scroll = $es->scrolled_search(
        {   index       => $self->index->name,
            type        => 'file',
            scroll      => '5m',
            size        => 1000,
            search_type => 'scan',
            query       => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            {   term =>
                                    { 'file.release' => $source->{release} }
                            },
                            {   term => { 'file.author' => $source->{author} }
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
            $status eq 'latest' ? "Upgrading " : "Downgrading ",
                "file ", $source->{name} || '';
        };
        push(
            @bulk,
            {   index => {
                    index => $self->index->name,
                    type  => 'file',
                    id    => $row->{_id},
                    data => { %$source, status => $status }
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

__END__

=head1 SYNOPSIS

 # bin/metacpan latest

 # bin/metacpan latest --dry_run
 
=head1 DESCRIPTION

After importing releases from cpan, this script will set the status
to latest on the most recent release, its files and dependencies.
It also makes sure that there is only one latest release per distribution.
