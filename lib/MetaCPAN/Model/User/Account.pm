package MetaCPAN::Model::User::Account;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

use MetaCPAN::Model::User::Identity;
use MetaCPAN::Types qw(:all);
use MooseX::Types::Structured qw(Dict);
use MetaCPAN::Util;

=head1 PROPERTIES

=head2 id

ID of user account.

=cut

has id => (
    id => 1,
    is => 'ro',
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
    is      => 'ro',
    clearer => 'clear_token',
    writer  => '_set_code',
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
    is  => 'ro',
    isa => 'DateTime',
);

=head2 looks_human

Certain features are disabled unless a user C<looks_human>. This attribute
is true if the user is connected to a PAUSE account or he L</passed_captcha>.

=cut

has looks_human => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_looks_human',
    clearer => 'clear_looks_human',
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
    timestamp => {},
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

        # Not every user is an author
        if ($profile) {
            $profile->_set_user( $self->id );
            $profile->put;
        }
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
