package MetaCPAN::Document::Dependency;
use Moose;
use ElasticSearch::Document;
use MetaCPAN::Util;

has id => ( id => [qw(author release module phase)] );

has [qw(phase relationship module author version release)];
has version_numified => ( isa => 'Num', lazy_build => 1 );
has status => ( default => 'cpan' );

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version )
}

__PACKAGE__->meta->make_immutable;
