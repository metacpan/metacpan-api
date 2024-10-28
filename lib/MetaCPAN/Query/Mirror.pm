package MetaCPAN::Query::Mirror;

use MetaCPAN::Moose;
use MetaCPAN::Util qw( hit_total );

use MetaCPAN::ESConfig qw( es_doc_path );

with 'MetaCPAN::Query::Role::Common';

sub search {
    my ( $self, $q ) = @_;
    my $query = { match_all => {} };

    if ($q) {
        my @protocols = grep /^ (?: http | ftp | rsync ) $/x, split /\s+/, $q;

        $query = {
            bool => {
                must => [ map +{ exists => { field => $_ } }, @protocols ]
            },
        };
    }

    my @sort = ( sort => [qw( continent country )] );

    my $location;

    if ( $q and $q =~ /loc\:([^\s]+)/ ) {
        $location = [ split( /,/, $1 ) ];
        if ($location) {
            @sort = (
                sort => {
                    _geo_distance => {
                        location => [ $location->[1], $location->[0] ],
                        order    => 'asc',
                        unit     => 'km'
                    }
                }
            );
        }
    }

    my $ret = $self->es->search(
        es_doc_path('mirror'),
        body => {
            size  => 999,
            query => $query,
            @sort,
        },
    );

    my $data = [
        map +{
            %{ $_->{_source} },
            distance => ( $location ? $_->{sort}[0] : undef )
        },
        @{ $ret->{hits}{hits} }
    ];

    return {
        mirrors => $data,
        total   => hit_total($ret),
        took    => $ret->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
