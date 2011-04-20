package MetaCPAN::Document::Module;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Util;

has name => ( index => 'analyzed' );
has version => ( required => 0 );
has version_numified => ( isa => 'Num', lazy_build => 1, required => 1 );

sub _build_version_numified {
    my $self = shift;
    return 0 unless($self->version);
    return MetaCPAN::Util::numify_version( $self->version );
}

__PACKAGE__->meta->make_immutable;