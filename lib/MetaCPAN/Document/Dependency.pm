package MetaCPAN::Document::Dependency;
use Moose;
use ElasticSearch::Document;
use version;

has [qw(phase relationship module version release)];
has version_numified => ( isa => 'Num', lazy_build => 1 );

sub _build_version_numified {
    return eval version->parse( shift->version )->numify;
}

__PACKAGE__->meta->make_immutable;
