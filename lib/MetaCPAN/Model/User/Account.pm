package MetaCPAN::Model::User::Account;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Model::User::Identity;
use MetaCPAN::Util;
use MooseX::Types::Structured qw(Dict);
use MooseX::Types::Moose qw(Str ArrayRef);
use MetaCPAN::Types qw(:all);

has id => ( id => 1, required => 0, is => 'rw' );

has identity => (
    is       => 'ro',
    required => 1,
    isa      => Identity,
    coerce   => 1,
    traits   => ['Array'],
    handles  => { add_identity => 'push' },
    default  => sub { [] }
);

has code => ( is => 'rw', clearer => 'clear_token' );

has access_token => (
    is       => 'ro',
    required => 1,
    isa      => ArrayRef [ Dict [ token => Str, client => Str ] ],
    default => sub                { [] },
    dynamic => 1,
    traits  => ['Array'],
    handles => { add_access_token => 'push' }
);

has passed_captcha => ( is => 'rw', isa => 'DateTime' );

has looks_human =>
    ( is => 'ro', isa => 'Bool', required => 1, lazy_build => 1 );

after add_identity => sub {
    my ( $self, $identity ) = @_;
    if ( $identity->{name} eq 'pause' ) {
        my $profile = $self->index->model->index('cpan')->type('author')
            ->get( $identity->{key} );
        return unless ($profile);
        $profile->user( $self->id );
        $profile->put;
    }
};

sub _build_looks_human {
    my $self = shift;
    return $self->has_identity('pause') || $self->passed_captcha;
}

sub has_identity {
    my ( $self, $identity ) = @_;
    return scalar grep { $_->name eq $identity } @{ $self->identity };
}

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
