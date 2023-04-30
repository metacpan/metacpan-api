package MetaCPAN::Query::CVE;

use MetaCPAN::Moose;

with 'MetaCPAN::Query::Role::Common';

sub find_cves_by_cpansa {
    my ( $self, $cpansa_id ) = @_;

    my $query = +{ term => { cpansa_id => $cpansa_id } };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'cve',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return +{ cve => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

sub find_cves_by_release {
    my ( $self, $release_id ) = @_;

    my $query = +{ match => { releases => $release_id } };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'cve',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return +{ cve => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

__PACKAGE__->meta->make_immutable;
1;
