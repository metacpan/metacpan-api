package MetaCPAN::Document::CVE::Set;

use Moose;

use MetaCPAN::Query::CVE ();

extends 'ElasticSearchX::Model::Document::Set';

has query_cve => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::CVE',
    lazy    => 1,
    builder => '_build_query_cve',
    handles => [ qw<
        find_cves_by_cpansa
        find_cves_by_release
        find_cves_by_dist
    > ],
);

sub _build_query_cve {
    my $self = shift;
    return MetaCPAN::Query::CVE->new( es => $self->es );
}

__PACKAGE__->meta->make_immutable;
1;
