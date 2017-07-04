package MetaCPAN::Document::Rating;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document::Types qw(:all);
use ElasticSearchX::Model::Document;

use MetaCPAN::Types qw( ArrayRef Bool Num Str );
use MooseX::Types::Structured qw( Dict );

has details => (
    is  => 'ro',
    isa => Dict [ documentation => Str ],
);

has rating => (
    required => 1,
    is       => 'ro',
    isa      => Num,
    builder  => '_build_rating',
);

has [qw(distribution release author user)] => (
    required => 1,
    is       => 'ro',
    isa      => Str,
);

has date => (
    required => 1,
    is       => 'ro',
    isa      => 'DateTime',
    default  => sub { DateTime->now },
);

has helpful => (
    required => 1,
    is       => 'ro',
    isa      => ArrayRef [ Dict [ user => Str, value => Bool ] ],
    default => sub { [] },
);

sub _build_rating {
    my $self = shift;
    die "Provide details to calculate a rating";
    my %details = %{ $self->details };
    my $rating  = 0;
    $rating += $_ for ( values %details );
    return $rating / scalar keys %details;
}

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Rating::Set;

use strict;
use warnings;

use Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

extends 'ElasticSearchX::Model::Document::Set';

sub by_distributions {
    my ( $self, $distributions ) = @_;

    my $body = {
        size         => 0,
        query        => { terms => { distribution => $distributions } },
        aggregations => {
            ratings => {
                terms => {
                    field => 'distribution'
                },
                aggregations => {
                    ratings_dist => {
                        stats => {
                            field => 'rating'
                        }
                    }
                }
            }
        }
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'rating',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my %distributions = map { $_->{key} => $_->{ratings_dist} }
        @{ $ret->{aggregations}{ratings}{buckets} };

    return {
        distributions => \%distributions,
        total         => $ret->{hits}{total},
        took          => $ret->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
