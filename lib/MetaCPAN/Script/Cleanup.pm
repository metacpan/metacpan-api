package MetaCPAN::Script::Cleanup;

use Moose;

use Log::Contextual qw( :log );
use MetaCPAN::Types qw( Bool Int );

use Digest::file qw( digest_file_hex );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Cleanup tools

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

has releases_missing_tarball => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has files_missing_tarball => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has files_missing_release => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

sub _cleanup_missing_tarball {
    my ( $self, $type ) = @_;

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => $type,
        scroll => '10m',
        body   => { query => { match_all => {} } },
        fields => [qw( id name download_url )],
    );

    my $count = 0;
    while ( my $r = $scroll->next ) {
        if ( $self->limit >= 0 && $count >= $self->limit ) {
            last;
        }

        my $file = $self->cpan . "/authors" . $r->{fields}{download_url}->[0]
            =~ s/^.*?authors//r;

        log_info { "Checking " . $file };

        if ( !-e $file ) {
            $count++;
            log_warn {
                "["
                    . uc($type) . "] "
                    . $r->{fields}{name}[0] . " ("
                    . $r->{_id}
                    . ") file is missing at "
                    . $file
            };
            last;
        }
    }

}

sub _cleanup_files_missing_release {

}

sub run {
    my $self = shift;

    if ( $self->releases_missing_tarball ) {
        $self->_cleanup_missing_tarball('release');
    }

    if ( $self->files_missing_tarball ) {
        $self->_cleanup_missing_tarball('file');
    }
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 # bin/metacpan cleanup --[no-]dry_run --limit X [--releases_missing_tarball]

=head1 DESCRIPTION

Cleanup tool for bad releases / info

=head2 dry_run

Don't update - just show what would have been updated

=head2 releases_missing_tarball

Cleanup releases whos file is not in CPAN (anymore)

=cut
