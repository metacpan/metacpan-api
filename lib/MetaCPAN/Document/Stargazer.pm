package MetaCPAN::Document::Stargazer;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

use DateTime;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Util;

has id => (
    is => 'ro',
    id => [qw(user module)],
);

has [qw(author release user module)] => (
    is       => 'ro',
    required => 1,
);

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
    default  => sub { DateTime->now },
);

has timestamp => (
    is        => 'ro',
    timestamp => { path => 'date', store => 1 },
);

__PACKAGE__->meta->make_immutable;
