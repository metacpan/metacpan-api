package MetaCPAN::Document::Module;
use Moose;
use ElasticSearch::Document;

use version;
use URI::Escape ();

has id => ( id => [qw(author release name)] );
has version_numified => ( isa => 'Num', lazy_build => 1 );
has [qw(author name distribution release file file_id)] => ();
has [qw(version)] => ( required => 0 );
has date     => ( isa   => 'DateTime' );
has abstract => ( index => 'analyzed' );

sub _build_version_numified {
    return eval version->parse( shift->version )->numify;
}

__PACKAGE__->meta->make_immutable;
