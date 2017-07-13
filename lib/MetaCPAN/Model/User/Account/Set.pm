package MetaCPAN::Model::User::Account::Set;

use Moose;
extends 'ElasticSearchX::Model::Document::Set';

=head1 SET METHODS

=head2 find

 $type->find({ name => "github", key => 123455 });

Find an account based on its identity.

=cut

sub find {
    my ( $self, $p ) = @_;
    return $self->filter(
        {
            and => [
                { term => { 'identity.name' => $p->{name} } },
                { term => { 'identity.key'  => $p->{key} } }
            ]
        }
    )->first;
}

=head2 find_code

 $type->find_code($code);

Find account by C<$code>. See L</code>.

=cut

sub find_code {
    my ( $self, $token ) = @_;
    return $self->filter( { term => { 'code' => $token } } )->first;
}

=head2 find_token

 $type->find_token($access_token);

Find account by C<$access_token>. See L</access_token>.

=cut

sub find_token {
    my ( $self, $token ) = @_;
    return $self->filter( { term => { 'access_token.token' => $token } } )
        ->first;
}

__PACKAGE__->meta->make_immutable;
1;
