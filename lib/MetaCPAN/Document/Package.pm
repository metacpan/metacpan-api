package MetaCPAN::Document::Package;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw( Str );

has module_name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has version => (
    is  => 'ro',
    isa => Str,
);

has file => (
    is  => 'ro',
    isa => Str,
);

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Package::Set;

use strict;
use warnings;

use Moose;

extends 'ElasticSearchX::Model::Document::Set';

sub get_modules {
    my ( $self, $dist, $ver ) = @_;

    my $query = +{
        query => {
            bool => {
                must => [
                    { term => { distribution => $dist } },
                    { term => { dist_version => $ver } },
                ],
            }
        }
    };

    my $res = $self->es->search(
        index => $self->index->name,
        type  => 'package',
        body  => {
            query   => $query,
            size    => 999,
            _source => [qw< module_name >],
        }
    );

    my $hits = $res->{hits}{hits};
    return [] unless @{$hits};
    return +{ modules => [ map { $_->{_source}{module_name} } @{$hits} ] };
}

__PACKAGE__->meta->make_immutable;
1;
