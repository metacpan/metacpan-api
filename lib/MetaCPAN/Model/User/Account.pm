package MetaCPAN::Model::User::Account;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

use List::Util      qw( first );
use MetaCPAN::Types qw( AccessTokens Identities );
use MetaCPAN::Util  qw(true false);

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
    isa      => Identities,
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
    isa      => AccessTokens,
    default  => sub { [] },
    dynamic  => 1,
    traits   => ['Array'],
    handles  => { add_access_token => 'push' },
);

=head1 METHODS

=head2 add_identity

Adds an identity to L</identity>. If the identity is a PAUSE account,
the user ID is added to the corresponding L<MetaCPAN::Document::Author> document.

=cut

after add_identity => sub {
    my ( $self, $identity ) = @_;
    if ( $identity->{name} eq 'pause' ) {
        my $profile
            = $self->index->model->doc('author')->get( $identity->{key} );

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
    return scalar grep { $_->{name} eq $identity } @{ $self->identity };
}

=head2 get_identities

=cut

sub get_identities {
    my ( $self, $identity ) = @_;
    return grep { $_->{name} eq $identity } @{ $self->identity };
}

=head2 remove_identity( $name, $key )

Removes the identities called C<$name> and returns the first one removed.
If C<$key> is given, it removes only the identity with that key, so an
account that holds two PAUSE IDs keeps the other one.

=cut

sub remove_identity {
    my ( $self, $identity, $key ) = @_;
    my $ids     = $self->identity;
    my $matches = sub {
        $_[0]->{name} eq $identity
            && ( !defined $key || $_[0]->{key} eq $key );
    };
    my $id = first { $matches->($_) } @$ids;
    @$ids = grep { !$matches->($_) } @$ids;
    return unless $id;

    if ( $identity eq 'pause' ) {
        my $profile = $self->index->model->doc('author')->get( $id->{key} );

        if (   $profile
            && defined $profile->user
            && $profile->user eq $self->id )
        {
            $profile->_clear_user;
            $profile->put;
        }
    }

    return $id;
}

__PACKAGE__->meta->make_immutable;
1;
