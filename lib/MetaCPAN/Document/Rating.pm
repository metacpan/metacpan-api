package MetaCPAN::Document::Rating;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document::Types qw(:all);
use ElasticSearchX::Model::Document;

use MooseX::Types::Moose qw(Int Num Bool Str ArrayRef HashRef Undef);
use MooseX::Types::Structured qw(Dict Tuple Optional);

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
1;
