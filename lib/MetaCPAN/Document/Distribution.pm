package MetaCPAN::Document::Distribution;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use ElasticSearchX::Model::Document;

use MetaCPAN::Types::TypeTiny qw( BugSummary RiverSummary );
use MetaCPAN::Util            qw(true false);

has name => (
    is       => 'ro',
    required => 1,
    id       => 1,
);

has bugs => (
    is      => 'ro',
    isa     => BugSummary,
    dynamic => 1,
    writer  => '_set_bugs',
);

has river => (
    is      => 'ro',
    isa     => RiverSummary,
    dynamic => 1,
    writer  => '_set_river',
    default => sub {
        +{
            bucket     => 0,
            bus_factor => 1,
            immediate  => 0,
            total      => 0,
        };
    },
);

sub releases {
    my $self = shift;
    return $self->index->model->doc("release")
        ->query( { term => { "distribution" => $self->name } } );
}

sub set_first_release {
    my $self = shift;

    my @releases = $self->releases->sort( ["date"] )->all;

    my $first = shift @releases;
    $first->_set_first(true);
    $first->put;

    for my $rel (@releases) {
        $rel->_set_first(false);
        $rel->put;
    }

    return $first;
}

__PACKAGE__->meta->make_immutable;

1;
