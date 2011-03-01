package MetaCPAN::Document::Module;
use Moose;
use ElasticSearch::Document;

use MetaCPAN::Util;
use URI::Escape ();

has id => ( id => [qw(author release name)] );
has version_numified => ( isa => 'Num', lazy_build => 1 );
has [qw(author distribution file file_id)] => ();
has release => ( parent => 1 );
has name => ( index => 'analyzed' );
has [qw(version)] => ( required => 0 );
has date     => ( isa   => 'DateTime' );
has abstract => ( index => 'analyzed' );
has status => ( default => 'cpan' );
has maturity => ( default => 'released' );

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version )
}

__PACKAGE__->meta->make_immutable;
