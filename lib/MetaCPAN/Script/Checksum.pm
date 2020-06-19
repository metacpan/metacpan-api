package MetaCPAN::Script::Checksum;

use Moose;

use Log::Contextual qw( :log );
use Types::Standard qw( Bool Int );

use Digest::file qw( digest_file_hex );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Fill checksums for releases

=cut

has limit => (
    is      => 'ro',
    isa     => Int,
    default => 1000,
);

has dry_run => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

sub run {
    my $self = shift;

    my $bulk;
    if ( !$self->dry_run ) {
        $bulk = $self->es->bulk_helper(
            index => $self->index->name,
            type  => 'release',
        );
    }
    else {
        log_warn {"--- DRY-RUN ---"};
    }

    log_info {"Searching for releases missing checksums"};

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'release',
        scroll => '10m',
        body   => {
            query => {
                not => {
                    exists => {
                        field => "checksum_md5"
                    }
                }
            }
        },
        fields => [qw( id name download_url )],
    );

    log_warn { "Found " . $scroll->total . " releases" };
    log_warn { "Limit is " . $self->limit };

    my $count = 0;

    while ( my $p = $scroll->next ) {
        if ( $self->limit >= 0 and $count++ >= $self->limit ) {
            log_info {"Max number of changes reached."};
            last;
        }

        log_info { "Adding checksums for " . $p->{fields}{name}->[0] };

        if ( my $download_url = $p->{fields}{download_url} ) {
            my $file
                = $self->cpan . "/authors" . $p->{fields}{download_url}->[0]
                =~ s/^.*authors//r;
            my $checksum_md5    = digest_file_hex( $file, 'MD5' );
            my $checksum_sha256 = digest_file_hex( $file, 'SHA-256' );

            if ( $self->dry_run ) {
                log_info { "--- MD5: " . $checksum_md5 }
                log_info { "--- SHA256: " . $checksum_sha256 }
            }
            else {
                $bulk->update(
                    {
                        id  => $p->{_id},
                        doc => {
                            checksum_md5    => $checksum_md5,
                            checksum_sha256 => $checksum_sha256
                        },
                        doc_as_upsert => 1,
                    }
                );
            }
        }
        else {
            log_info {
                $p->{fields}{name}->[0] . " is missing a download_url"
            };
        }
    }

    if ( !$self->dry_run ) {
        $bulk->flush;
    }

    log_info {'Finished adding checksums'};
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 # bin/metacpan checksum --[no-]dry_run --limit X

=head1 DESCRIPTION

Backfill checksums for releases

=head2 dry_run

Don't update - just show what would have been updated (default)

=head2 no-dry_run

Update records

=head2 limit

Max number of records to update. default=1000, for unlimited set to -1

=cut
