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
    return unless @users;
    return $self->es_by_terms_vals(
        req => $req,
        -or => +{ user => \@users }
    );
}

sub by_distribution {
    my ( $self, $req ) = @_;
    my $distribution = $req->read_param('distribution');
    return unless $distribution;
    return $self->es_by_terms_vals(
        req  => $req,
        -and => +{ distribution => $distribution }
    );
}

sub leaderboard {
    my ( $self, $req ) = @_;
    my $size = $req->parameters->{'size'};
    $size ||= 600;

    my $data = $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            query => { match_all => {} },
            size  => 0,
            aggs  => {
                leaderboard =>
                    { terms => { field => 'distribution', size => $size } }
            },
        }
    );

    return +{
        leaders => [
            @{ $data->{aggregations}->{leaderboard}->{buckets} }[ 0 .. 99 ]
        ],
        took  => $data->{took},
        total => $data->{hits}->{total},
    };
}

sub recent {
    my ( $self, $req )  = @_;
    my ( $size, $page ) = @{ $req->parameters }{qw< size page >};
    $size ||= 20;
    $page ||= 1;
    return $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            query => { match_all => {} },
            size  => $size,
            from  => ( $page - 1 ) * $size,
            sort => [ { 'date' => { order => 'desc' } } ],
        }
    );
}

sub agg_dists_user {
    my ( $self, $req ) = @_;
    my $user          = $req->read_param('user');
    my @distributions = $req->read_param('distribution');
    return unless @distributions;

    my $query = {
        filtered => {
            query  => { match_all => {} },
            filter => {
                or => [
                    map { { term => { 'distribution' => $_ } } }
                        @distributions
                ]
            }
        }
    };

    my $aggs = {
        favorites => {
            terms => {
                field => 'distribution',
                size  => scalar @distributions,
            },
        }
    };

    if ($user) {
        $aggs->{'myfavorites'} = {
            filter       => { term => { 'user' => $user } },
            aggregations => {
                enteries => {
                    terms => { field => 'distribution' }
                }
            }
        };
    }

    my $data = $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            query => $query,
            aggs  => $aggs,
            size  => 0,
        }
    );

    my $favorites = { map { $_->{key} => $_->{doc_count} }
            @{ $data->{aggregations}->{favorites}->{buckets} } };

    my $myfavorites = {};
    if ($user) {
        $myfavorites = {
            map { $_->{key} => $_->{doc_count} } @{
                $data->{aggregations}->{myfavorites}->{entries}->{buckets}
            }
        };
    }

    return +{
        took        => $data->{took},
        favorites   => $favorites,
        myfavorites => $myfavorites,
    };
}

__PACKAGE__->meta->make_immutable;
1;
