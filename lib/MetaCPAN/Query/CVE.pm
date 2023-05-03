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

    return +{ cve => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

sub find_cves_by_release {
    my ( $self, $author, $release ) = @_;

    my $query = +{ match => { releases => "$author/$release" } };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'cve',
        body  => {
            query => $query,
            size  => 999,
        }
    );

    return +{ cve => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

sub find_cves_by_dist {
    my ( $self, $dist, $version ) = @_;

    my $query = +{
        match => {
            dist => $dist,
            ( defined $version ? ( versions => $version ) : () ),
        }
    };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'cve',
        body  => {
            query => $query,
            size  => 999,
        }
    );

    return +{ cve => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

__PACKAGE__->meta->make_immutable;
1;
