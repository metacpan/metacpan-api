package MetaCPAN::Plack::Mirror;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub type { 'mirror' }

sub handle {
    my ( $self, $req ) = @_;
    $self->get_source($req);
}

1;

__END__

=head1 METHODS

=head2 index

Returns C<mirror>.

=head2 handle

Calls L<MetaCPAN::Plack::Base/get_source>.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>
