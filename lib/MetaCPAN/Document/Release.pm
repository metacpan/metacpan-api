package MetaCPAN::Document::Release;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Document::Author;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Util;

has [qw(license version author archive)] => ();
has date             => ( isa        => 'DateTime' );
has download_url     => ( lazy_build => 1 );
has name             => ( id         => 1, index => 'analyzed' );
has version_numified => ( isa        => 'Num', lazy_build => 1 );
has resources        => ( isa        => Resources, required => 0, coerce => 1 );
has abstract => ( index => 'analyzed' );
has distribution => ( analyzer => 'lowercase' );
has status => ( default => 'cpan' );
has maturity => ( default => 'released' );
has stat => ( isa => Stat, required => 0 );

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version )
}

sub _build_download_url {
    my $self = shift;
    'http://cpan.cpantesters.org/authors/'
      . MetaCPAN::Document::Author::_build_dir( $self->author ) . '/'
      . $self->archive;
}

__PACKAGE__->meta->make_immutable;
