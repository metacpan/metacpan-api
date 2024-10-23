package MetaCPAN::Document::Cover::Set;

use Moose;

use MetaCPAN::Query::Cover ();

extends 'ElasticSearchX::Model::Document::Set';

has query_cover => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Cover',
    lazy    => 1,
    builder => '_build_query_cover',
    handles => [qw< find_release_coverage >],
);

sub _build_query_cover {
    my $self = shift;
    return MetaCPAN::Query::Cover->new( es => $self->es );
}

__PACKAGE__->meta->make_immutable;
1;
