package MetaCPAN::Model::User::Account;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

use MetaCPAN::Model::User::Identity ();
use MetaCPAN::Types                 qw( ESBool Identity );
use MetaCPAN::Types::TypeTiny       qw( ArrayRef Dict Str );
use MetaCPAN::Util                  qw(true false);

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
    return scalar grep { $_->name eq $identity } @{ $self->identity };
}

=head2 get_identities

=cut

sub get_identities {
    my ( $self, $identity ) = @_;
    return grep { $_->name eq $identity } @{ $self->identity };
}

sub remove_identity {
    my ( $self, $identity ) = @_;
    my $ids  = $self->identity;
    my ($id) = grep { $_->{name} eq $identity } @$ids;
    @$ids = grep { $_->{name} ne $identity } @$ids;

    if ( $identity eq 'pause' ) {
        my $profile = $self->index->model->doc('author')->get( $id->{key} );

        if ( $profile && $profile->user eq $self->id ) {
            $profile->_clear_user;
            $profile->put;
        }
    }

    return $id;
}

__PACKAGE__->meta->make_immutable;
1;
