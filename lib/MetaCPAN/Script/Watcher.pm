package MetaCPAN::Script::Watcher;

use strict;
use warnings;
use Moose;

use CPAN::DistnameInfo ();
use Cpanel::JSON::XS   qw( decode_json );
use Log::Contextual    qw( :log );
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Types    qw( Bool );
use MetaCPAN::Util     qw( true false );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has dry_run => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

my $fails = 0;

my @segments = qw(1h 6h 1d 1W 1M 1Q 1Y Z);

sub run {
    my $self = shift;
    while (1) {
        my $latest = eval { $self->latest_release };
        if ($@) {
            log_error {"getting latest release failed: $@"};
            sleep(15);
            next;
        }
        my @changes = $self->changes($latest);
        while ( my $release = pop(@changes) ) {
            $release->{type} eq 'delete'
                ? $self->reindex_release($release)
                : $self->index_release($release);
        }
        sleep(15);
    }
}

sub changes {
    my $self    = shift;
    my $latest  = shift;
    my $archive = $latest->archive;
    my %seen;
    my @changes;
SEGMENTS: for my $segment (@segments) {
        log_debug {"Loading RECENT-$segment.json"};
        my $json
            = decode_json(
            $self->cpan->child("RECENT-$segment.json")->slurp );
        for (
            grep {
                $_->{path}
                    =~ /^authors\/id\/.*\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/
            } @{ $json->{recent} }
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
            elsif ( $_->{epoch} < $latest->date->epoch ) {
                last SEGMENTS;
            }
            push( @changes, $_ );
        }
        if ( $json->{meta}->{minmax}->{min} < $latest->date->epoch ) {
            log_debug {"Includes latest release"};
            last;
        }
    }
    return @changes;
}

sub latest_release {
    my $self = shift;
    return $self->model->doc('release')
        ->sort( [ { 'date' => { order => "desc" } } ] )
        ->first;
}

sub index_release {
    my ( $self, $release ) = @_;
    my $archive = $self->cpan->child( $release->{path} )->stringify;
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
        'release', $archive, '--latest', '--queue'
    );
    log_debug {"Running @run"};
    system(@run) unless ( $self->dry_run );
}

sub reindex_release {
    my ( $self, $release ) = @_;
    my $info = CPAN::DistnameInfo->new( $release->{path} );
    $release = $self->model->doc('release')->query( {
        bool => {
            must => [
                { term => { author  => $info->cpanid } },
                { term => { archive => $info->filename } },
            ],
        },
    } )->raw->first;
    return unless ($release);
    log_info {"Moving $release->{_source}->{name} to BackPAN"};

    my $es     = $self->es;
    my $scroll = $es->scroll_helper( {
        es_doc_path('file'),
        scroll => '1m',
        body   => {
            query => {
                bool => {
                    must => [
                        {
                            term => {
                                release => $release->{_source}->{name}
                            }
                        },
                        {
                            term => {
                                author => $release->{_source}->{author}
                            }
                        },
                    ],
                },
            },
            size    => 1000,
            _source => true,
            sort    => '_doc',
        },
    } );
    return if ( $self->dry_run );

    my %bulk_helper;
    for (qw/ file release /) {
        $bulk_helper{$_} = $self->es->bulk_helper( es_doc_path($_) );
    }

    while ( my $row = $scroll->next ) {
        my $source = $row->{_source};
        $bulk_helper{file}->index( {
            id     => $row->{_id},
            source => {
                %$source, status => 'backpan',
            }
        } );
    }

    $bulk_helper{release}->index( {
        id     => $release->{_id},
        source => {
            %{ $release->{_source} }, status => 'backpan',
        }
    } );

    for my $bulk ( values %bulk_helper ) {
        $bulk->flush;
    }

    # Call Fastly to purge
    $self->purge_cpan_distnameinfos( [$info] );
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

=cut
