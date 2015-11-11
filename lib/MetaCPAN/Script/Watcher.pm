package MetaCPAN::Script::Watcher;

use strict;
use warnings;

use CPAN::DistnameInfo;
use JSON::XS;
use Log::Contextual qw( :log );
use MetaCPAN::Util;
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has backpan => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'update deleted archives only',
);

has dry_run => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

my $fails  = 0;
my $latest = 0;

my @segments = qw(1h 6h 1d 1W 1M 1Q 1Y Z);

#my @segments = qw(1Y);

sub run {
    my $self = shift;
    while (1) {
        $latest = eval { $self->latest_release };
        if ($@) {
            log_error {"getting latest release failed: $@"};
            sleep(15);
            next;
        }
        my @changes
            = $self->backpan ? $self->backpan_changes : $self->changes;
        while ( my $release = pop(@changes) ) {
            $release->{type} eq 'delete'
                ? $self->reindex_release($release)
                : $self->index_release($release);
        }
        last if ( $self->backpan );
        sleep(15);
    }
}

sub changes {
    my $self    = shift;
    my $now     = DateTime->now->epoch;
    my $archive = $latest->archive;
    my %seen;
    my @changes;
    for my $segment (@segments) {
        log_debug {"Loading RECENT-$segment.json"};
        my $json
            = decode_json( $self->cpan->file("RECENT-$segment.json")->slurp );
        for (
            grep {
                $_->{path}
                    =~ /^authors\/id\/.*\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/
            } grep { $self->backpan ? $_->{type} eq "delete" : 1 }
            @{ $json->{recent} }
            )
        {
            my $info = CPAN::DistnameInfo->new( $_->{path} );
            my $path = $info->cpanid . "/" . $info->filename;
            my $seen = $seen{$path};
            next
                if ( $seen
                && ( $_->{type} eq $seen->{type} || $_->{type} eq 'delete' )
                );
            $seen{$path} = $_;
            if ( $_->{path} =~ /\/\Q$archive\E$/ ) {
                last;
            }
            push( @changes, $_ );
        }
        if (  !$self->backpan
            && $json->{meta}->{minmax}->{min} < $latest->date->epoch )
        {
            log_debug {"Includes latest release"};
            last;
        }
    }
    return @changes;
}

sub backpan_changes {
    my $self   = shift;
    my $scroll = $self->es->scrolled_search(
        {
            size   => 1000,
            scroll => '1m',
            index  => $self->index->name,
            type   => 'release',
            fields => [qw(author archive)],
            query  => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        not =>
                            { filter => { term => { status => 'backpan' } } }
                    },
                }
            },
        }
    );
    my @changes;
    while ( my $release = $scroll->next ) {
        my $data = $release->{fields};
        my $path
            = $self->cpan->file( 'authors',
            MetaCPAN::Util::author_dir( $data->{author} ),
            $data->{archive} );
        next if ( -e $path );
        log_debug {"$path not in the CPAN"};
        push( @changes, { path => $path, type => 'delete' } );
    }
    return @changes;
}

sub latest_release {
    my $self = shift;
    return undef if ( $self->backpan );
    return $self->index->type('release')
        ->sort( [ { 'date' => { order => "desc" } } ] )->first;
}

sub skip {
    my ( $self, $author, $archive ) = @_;
    return $self->index->type('release')->filter(
        {
            and => [
                { term => { status  => 'backpan' } },
                { term => { archive => $archive } },
                { term => { author  => $author } },
            ]
        }
    )->inflate(0)->count;
}

sub index_release {
    my ( $self, $release ) = @_;
    my $archive = $self->cpan->file( $release->{path} )->stringify;
    for ( my $i = 0; $i < 15; $i++ ) {
        last if ( -e $archive );
        log_debug {"Archive $archive does not yet exist"};
        sleep(1);
    }

    unless ( -e $archive ) {
        log_error {
            "Aborting, archive $archive not available after 15 seconds";
        };
        return;
    }

    my @run = (
        $FindBin::RealBin . "/metacpan",
        'release', $archive, '--latest', '--index', $self->index->name
    );
    log_debug {"Running @run"};
    system(@run) unless ( $self->dry_run );
}

sub reindex_release {
    my ( $self, $release ) = @_;
    my $info = CPAN::DistnameInfo->new( $release->{path} );
    $release = $self->index->type('release')->filter(
        {
            and => [
                { term => { author  => $info->cpanid } },
                { term => { archive => $info->filename } },
            ]
        }
    )->inflate(0)->first;
    return unless ($release);
    log_info {"Moving $release->{_source}->{name} to BackPAN"};

    my $es     = $self->es;
    my $scroll = $es->scroll_helper(
        {
            index       => $self->index->name,
            type        => 'file',
            scroll      => '1m',
            size        => 1000,
            search_type => 'scan',
            fields      => [ '_parent', '_source' ],
            query       => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            {
                                term => {
                                    'file.release' =>
                                        $release->{_source}->{name}
                                }
                            },
                            {
                                term => {
                                    'file.author' =>
                                        $release->{_source}->{author}
                                }
                            }
                        ]
                    }
                }
            }
        }
    );
    return if ( $self->dry_run );
    my @bulk;

    while ( my $row = $scroll->next ) {
        my $source = $row->{_source};
        push(
            @bulk,
            {
                index => {
                    index => $self->index->name,
                    type  => 'file',
                    id    => $row->{_id},
                    $row->{fields}->{_parent}
                    ? ( parent => $row->{fields}->{_parent} )
                    : (),
                    data => { %$source, status => 'backpan' }
                }
            }
        );
        if ( @bulk > 100 ) {
            $self->es->bulk( \@bulk );
            @bulk = ();
        }
    }
    push(
        @bulk,
        {
            index => {
                index => $self->index->name,
                type  => 'release',
                id    => $release->{_id},
                data  => { %{ $release->{_source} }, status => 'backpan' },
            }
        }
    );
    $self->es->bulk( \@bulk ) if (@bulk);

}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 # bin/metacpan watcher

=head1 DESCRIPTION

This script requires a local CPAN mirror. It watches the RECENT-*.json
files for changes to the CPAN directory every 15 seconds. New uploads
as well as deletions are processed sequentially.

=head1 OPTIONS

=head2 --backpan

This will look for the most recent release that has been deleted.
From that point on, it will look in the RECENT files for new deletions
and process them.

L<http://friendfeed.com/cpan>

=cut
