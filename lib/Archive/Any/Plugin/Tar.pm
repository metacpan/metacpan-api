package Archive::Any::Plugin::Tar;
use strict;
use base 'Archive::Any::Plugin';

use Archive::Tar;
use Cwd;

=head1 NAME

Archive::Any::Plugin::Tar - Archive::Any wrapper around Archive::Tar

=head1 SYNOPSIS

Do not use this module directly.  Instead, use Archive::Any.

=cut

sub can_handle {
    return(
           'application/x-tar',
           'application/x-gtar',
           'application/x-gzip',
           'application/x-bzip2',
          );
}

sub files {
    my( $self, $file ) = @_;
    my $t = Archive::Tar->new( $file );
    return $t->list_files;
}

sub extract {
    my ( $self, $file ) = @_;

    my $t = Archive::Tar->new( $file );
    return $t->extract;
}

sub type {
    my $self = shift;
    return 'tar';
}

=head1 SEE ALSO

Archive::Any, Archive::Tar

=cut

1;