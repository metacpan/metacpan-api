package ElasticSearchX::Model::Document::Role;
use strict;
use warnings;

use MetaCPAN::Model::Hacks;

no warnings 'redefine';

my $_put = \&_put;
*_put = sub {
    my ($self) = @_;
    my $es = $self->index->model->es;

    my %return = &$_put;

    delete $return{type};
    return %return;
};

1;
