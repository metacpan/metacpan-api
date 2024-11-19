package MetaCPAN::Query::Contributor;

use MetaCPAN::Moose;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw(hit_total);

with 'MetaCPAN::Query::Role::Common';

sub find_release_contributors {
    my ( $self, $author, $name ) = @_;

    my $query = +{
        bool => {
            must => [
                { term   => { release_author => $author } },
                { term   => { release_name   => $name } },
                { exists => { field          => 'pauseid' } },
            ]
        }
    };

    my $res = $self->es->search(
        es_doc_path('contributor'),
        body => {
            query   => $query,
            size    => 999,
            _source => [ qw(
                distribution
                pauseid
                release_author
                release_name
            ) ],
        }
    );
    hit_total($res) or return {};

    return +{
        contributors => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

sub find_author_contributions {
    my ( $self, $pauseid ) = @_;

    my $query = +{ term => { pauseid => $pauseid } };

    my $res = $self->es->search(
        es_doc_path('contributor'),
        body => {
            query   => $query,
            size    => 999,
            _source => [ qw(
                distribution
                pauseid
                release_author
                release_name
            ) ],
        }
    );
    hit_total($res) or return {};

    return +{
        contributors => [ map { $_->{_source} } @{ $res->{hits}{hits} } ] };
}

__PACKAGE__->meta->make_immutable;
1;
