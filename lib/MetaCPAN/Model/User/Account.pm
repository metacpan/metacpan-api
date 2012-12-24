package MetaCPAN::Model::User::Account;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Model::User::Identity;
use MetaCPAN::Util;
use MooseX::Types::Structured qw(Dict);
use MooseX::Types::Moose qw(Str ArrayRef);
use MetaCPAN::Types qw(:all);

=head1 PROPERTIES

=head2 id

ID of user account.

=cut

has id => (
    id       => 1,
    required => 0,
    is       => 'rw',
);

=head2 identity

Array of L<MetaCPAN::Model::User::Identity> objects. Each identity is a
authentication provider such as Twitter or GitHub.

=cut

has identity => (
    is       => 'ro',
    required => 1,
    isa      => Identity,
    coerce   => 1,
    traits   => ['Array'],
    handles  => { add_identity => 'push' },
    default  => sub { [] },
);

=head2 code

The code attribute is used temporarily when authenticating using OAuth.

=cut

has code => (
    is      => 'rw',
    clearer => 'clear_token',
);

=head2 access_token

Array of access token that allow third-party applications to authenticate
as the user.

=cut

has access_token => (
    is       => 'ro',
    required => 1,
    isa      => ArrayRef [ Dict [ token => Str, client => Str ] ],
    default => sub                { [] },
    dynamic => 1,
    traits  => ['Array'],
    handles => { add_access_token => 'push' },
);

=head2 passed_captcha

L<DateTime> when the user passed the captcha.

=cut

has passed_captcha => (
    is  => 'rw',
    isa => 'DateTime',
);

=head2 looks_human

Certain features are disabled unless a user C<looks_human>. This attribute
is true if the user is connected to a PAUSE account or he L</passed_captcha>.

=cut

has looks_human => (
    is         => 'ro',
    isa        => 'Bool',
    required   => 1,
    lazy_build => 1,
    clearer    => 'clear_looks_human',
);

sub _build_looks_human {
    my $self = shift;
    return $self->has_identity('pause') || ( $self->passed_captcha ? 1 : 0 );
}

=head2 timestamp

Sets the C<_timestamp> field.

=cut

has timestamp => (
    is        => 'ro',
    timestamp => { store => 1 },
);

=head1 METHODS

=head2 add_identity

Adds an identity to L</identity>. If the identity is a PAUSE account,
the user ID is added to the corresponding L<MetaCPAN::Document::Author> document
and L</looks_human> is updated.

=cut

after add_identity => sub {
    my ( $self, $identity ) = @_;
    if ( $identity->{name} eq 'pause' ) {
        $self->clear_looks_human;
        my $profile = $self->index->model->index('cpan')->type('author')
            ->get( $identity->{key} );
        $profile->user( $self->id ) if ($profile);
        $profile->put;
    }
};

=head2 has_identity

=cut

sub has_identity {
    my ( $self, $identity ) = @_;
    return scalar grep { $_->name eq $identity } @{ $self->identity };
}

=head2 get_identities

=cut

sub get_identities {
    my ( $self, $identity ) = @_;
    return grep { $_->name eq $identity } @{ $self->identity };
}

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Model::User::Account::Set;

use Moose;
extends 'ElasticSearchX::Model::Document::Set';

sub find {
    my ( $self, $p ) = @_;
    return $self->filter(
        {   and => [
                { term => { 'account.identity.name' => $p->{name} } },
                { term => { 'account.identity.key'  => $p->{key} } }
            ]
        }
    )->first;
}

sub find_code {
    my ( $self, $token ) = @_;
    return $self->filter( { term => { 'account.code' => $token } } )->first;
}

sub find_token {
    my ( $self, $token ) = @_;
    return $self->filter(
        { term => { 'account.access_token.token' => $token } } )->first;
}

__PACKAGE__->meta->make_immutable;
