package MetaCPAN::Query::Distribution;

use MetaCPAN::Moose;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw(hit_total);

with 'MetaCPAN::Query::Role::Common';

sub rogue_list {
    return qw(
        Acme-DependOnEverything
        Bundle-Everything
        kurila
        perl-5.005_02+apache1.3.3+modperl
        perlbench
        perl_debug
        perl_mlb
        pod2texi
        spodcxx
    );
}

sub get_river_data_by_dist {
    my ( $self, $dist ) = @_;

    my $query = +{
        bool => {
            must => [ { term => { name => $dist } }, ]
        }
    };

    my $res = $self->es->search(
        es_doc_path('distribution'),
        body => {
            query => $query,
            size  => 999,
        }
    );
    hit_total($res) or return {};

    return +{ river => +{ $dist => $res->{hits}{hits}[0]{_source}{river} } };
}

sub get_river_data_by_dists {
    my ( $self, $dist ) = @_;

    my $query = +{
        bool => {
            must => [ { terms => { name => $dist } }, ]
        }
    };

    my $res = $self->es->search(
        es_doc_path('distribution'),
        body => {
            query => $query,
            size  => 999,
        }
    );
    hit_total($res) or return {};

    return +{
        river => +{
            map { $_->{_source}{name} => $_->{_source}{river} }
                @{ $res->{hits}{hits} }
        },
    };
}

__PACKAGE__->meta->make_immutable;
1;
