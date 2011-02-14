package MetaCPAN::Document::Release;
use Moose;
use ElasticSearch::Document;
use MetaCPAN::Document::Author;

use MetaCPAN::Util;

has [qw(license version abstract status archive)] => ();
has date             => ( isa        => 'DateTime' );
has download_url     => ( lazy_build => 1 );
has name             => ( id         => 1 );
has version_numified => ( isa        => 'Num', lazy_build => 1 );
has resources        => ( isa        => 'HashRef', required => 0 );
has author       => ();
has distribution => ();

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version )
}

sub _build_download_url {
    my $self = shift;
    'http://cpan.metacpan.org/authors/'
      . MetaCPAN::Document::Author::_build_dir( $self->author ) . '/'
      . $self->archive;
}

__PACKAGE__->meta->make_immutable;
