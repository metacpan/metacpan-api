package MetaCPAN::Document::Favorite;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(:all);
use DateTime;
use MetaCPAN::Util;

has id => ( id => [qw(user distribution)] );
has release_id => ( is => 'ro', required => 1, parent => 1, lazy_build => 1 );
has [qw(author release user distribution)] => ( is => 'ro', required => 1 );
has date => ( is => 'ro', isa => 'DateTime', default => sub { DateTime->now } );

sub _build_release_id {
    my $self = shift;
    return MetaCPAN::Util::digest($self->author, $self->release);
}

__PACKAGE__->meta->make_immutable;
