package MetaCPAN::Document::CVE::Set;

use Moose;

use MetaCPAN::Query::CVE ();

extends 'ElasticSearchX::Model::Document::Set';

has query_cve => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::CVE',
    lazy    => 1,
    builder => '_build_query_cve',
    handles => [qw< find_cves_by_cpansa >],
);

sub _build_query_cve {
    my $self = shift;
    return MetaCPAN::Query::CVE->new(
        es         => $self->es,
        index_name => 'cve',
    );
}

__PACKAGE__->meta->make_immutable;
1;
