package MetaCPAN::Document::Favorite;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(:all);
use DateTime;
use MetaCPAN::Util;

has id => ( is => 'ro', id => [qw(user distribution)] );
has [qw(author release user distribution)] => ( is => 'ro', required => 1 );
has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
    default  => sub { DateTime->now }
);

sub _build_release_id {
    my $self = shift;
    return MetaCPAN::Util::digest( $self->author, $self->release );
}

__PACKAGE__->meta->make_immutable;
