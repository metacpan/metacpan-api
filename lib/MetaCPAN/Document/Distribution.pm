package MetaCPAN::Document::Distribution;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use ElasticSearchX::Model::Document;

use MetaCPAN::Types qw( ArrayRef BugSummary RiverSummary);

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
);

sub releases {
    my $self = shift;
    return $self->index->type("release")
        ->filter( { term => { "release.distribution" => $self->name } } );
}

sub set_first_release {
    my $self = shift;
    $self->unset_first_release;
    my $release = $self->releases->sort( ["date"] )->first;
    return unless $release;
    return $release if $release->first;
    $release->_set_first(1);
    $release->put;
    return $release;
}

sub unset_first_release {
    my $self = shift;
    my $releases
        = $self->releases->filter( { term => { "release.first" => \1 }, } )
        ->size(200)->scroll;
    while ( my $release = $releases->next ) {
        $release->_set_first(0);
        $release->update;
    }
    $self->index->refresh if $releases->total;
    return $releases->total;
}

__PACKAGE__->meta->make_immutable;

1;
