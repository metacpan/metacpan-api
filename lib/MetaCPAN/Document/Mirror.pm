package MetaCPAN::Document::Mirror;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document::Types qw( Location );
use ElasticSearchX::Model::Document;

use MetaCPAN::Types qw( ArrayRef Dict Str );
use MooseX::Types::Structured qw(Dict );    # not sure why I have to do this

has name => (
    is       => 'ro',
    required => 1,
    id       => 1,
);

has [qw(org city region country continent)] => (
    is    => 'ro',
    index => 'analyzed',
);

has [qw(tz src http rsync ftp freq note dnsrr ccode aka_name A_or_CNAME)] =>
    ( is => 'ro' );

has location => (
    is     => 'ro',
    isa    => Location,
    coerce => 1,
);

has contact => (
    is       => 'ro',
    required => 1,
    isa      => Dict [ contact_site => Str, contact_user => Str ],
);

has [qw(inceptdate reitredate)] => (
    is     => 'ro',
    isa    => 'DateTime',
    coerce => 1,
);

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Mirror::Set;

use strict;
use warnings;

use Moose;

extends 'ElasticSearchX::Model::Document::Set';

sub search {
    my ( $self, $q ) = @_;
    my $query = { match_all => {} };

    if ($q) {
        my @protocols = grep /^ (?: http | ftp | rsync ) $/x, split /\s+/, $q;

        my $query = {
            bool => {
                must_not => {
                    bool => {
                        should => [
                            map +{ filter => { missing => { field => $_ } } },
                            @protocols
                        ]
                    }
                }
            }
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
        index => $self->index->name,
        type  => 'mirror',
        body  => {
            size  => 999,
            query => $query,
            @sort,
        },
    );
    return unless $ret->{hits}{total};

    my $data = [
        map +{
            %{ $_->{_source} },
            distance => ( $location ? $_->{sort}[0] : undef )
        },
        @{ $ret->{hits}{hits} }
    ];

    return {
        mirrors => $data,
        total   => $ret->{hits}{total},
        took    => $ret->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
