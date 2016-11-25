package MetaCPAN::Document::Favorite;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;

use DateTime;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Util;

has id => (
    is => 'ro',
    id => [qw(user distribution)],
);

has [qw(author release user distribution)] => (
    is       => 'ro',
    required => 1,
);

=head2 date

L<DateTime> when the item was created.

=cut

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
    default  => sub { DateTime->now },
);

__PACKAGE__->meta->make_immutable;


package MetaCPAN::Document::Favorite::Set;

use MetaCPAN::Moose;
extends 'ElasticSearchX::Model::Document::Set';

with 'MetaCPAN::Role::ES::Query';

sub by_user {
    my ( $self, $req ) = @_;
    my @users = $req->read_param('user');
    return $self->es_by_terms_vals(
        req => $req,
        -or => +{ user => \@users }
    );
}

sub by_distribution {
    my ( $self, $req ) = @_;
    my $distribution = $req->read_param('distribution');
    return $self->es_by_terms_vals(
        req  => $req,
        -and => +{ distribution => $distribution }
    );
}

__PACKAGE__->meta->make_immutable;
1;
