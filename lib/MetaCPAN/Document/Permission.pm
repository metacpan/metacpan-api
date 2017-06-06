package MetaCPAN::Document::Permission;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw( ArrayRef Str );

has module_name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has owner => (
    is  => 'ro',
    isa => Str,
);

has co_maintainers => (
    is  => 'ro',
    isa => ArrayRef,
);

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Permission::Set;

use strict;
use warnings;

use Moose;
use Ref::Util qw( is_arrayref );

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

extends 'ElasticSearchX::Model::Document::Set';

sub by_author {
    my ( $self, $pauseid ) = @_;

    my $body = {
        query => {
            bool => {
                should => [
                    { term => { owner          => $pauseid } },
                    { term => { co_maintainers => $pauseid } },
                ],
            },
        },
        size => 5_000,
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'permission',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [
        sort { $a->{module_name} cmp $b->{module_name} }
        map  { $_->{_source} } @{ $ret->{hits}{hits} }
    ];

    return { permissions => $data };
}

sub by_modules {
    my ( $self, $modules ) = @_;
    $modules = [$modules] unless is_arrayref($modules);

    my @modules = map +{ term => { module_name => $_ } }, @{$modules};

    my $body = {
        query => {
            bool => { should => \@modules }
        },
        size => 1_000,
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'permission',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [
        sort { $a->{module_name} cmp $b->{module_name} }
        map  { $_->{_source} } @{ $ret->{hits}{hits} }
    ];

    return { permissions => $data };
}

__PACKAGE__->meta->make_immutable;
1;
