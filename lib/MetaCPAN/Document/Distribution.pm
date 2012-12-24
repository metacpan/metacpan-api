package MetaCPAN::Document::Distribution;

use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(BugSummary);
use MooseX::Types::Moose qw(ArrayRef);
use namespace::autoclean;

has name => ( is => 'ro', required => 1, id => 1 );
has bugs => (
    is      => 'rw',
    isa     => BugSummary,
    dynamic => 1,
);

sub releases {
	my $self = shift;
	return $self->index->type("release")->filter({
		term => { "release.distribution" => $self->name }
	});
}

sub set_first_release {
	my $self = shift;
	$self->unset_first_release;
	my $release = $self->releases->sort(["date"])->first;
	return unless $release;
	return $release if $release->first;
	$release->first(1);
	$release->update;
	return $release;
}

sub unset_first_release {
	my $self = shift;
	my $releases = $self->releases->filter({
		term => { "release.first" => \1 },
	})->size(200)->scroll;
	while(my $release = $releases->next) {
		$release->first(0);
		$release->update;
	}
	$self->index->refresh if $releases->total;
	return $releases->total;
}

__PACKAGE__->meta->make_immutable;

1;
