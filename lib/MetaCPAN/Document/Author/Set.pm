package MetaCPAN::Document::Author::Set;

use strict;
use warnings;

use Moose;
extends 'ElasticSearchX::Model::Document::Set';

use Ref::Util qw( is_arrayref );

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

sub by_ids {
    my ( $self, $ids ) = @_;

    map {uc} @{$ids};

    my $body = {
        query => {
            constant_score => {
                filter => { ids => { values => $ids } }
            }
        },
        size => scalar @{$ids},
    };

    my $authors = $self->es->search(
        index => $self->index->name,
        type  => 'author',
        body  => $body,
    );
    return {} unless $authors->{hits}{total};

    my @authors = map {
        single_valued_arrayref_to_scalar( $_->{_source} );
        $_->{_source}
    } @{ $authors->{hits}{hits} };

    return { authors => \@authors };
}

sub by_user {
    my ( $self, $users ) = @_;
    $users = [$users] unless is_arrayref($users);

    my $authors = $self->es->search(
        index => $self->index->name,
        type  => 'author',
        body  => {
            query => { terms => { user => $users } },
            size  => 100,
        }
    );
    return {} unless $authors->{hits}{total};

    my @authors = map {
        single_valued_arrayref_to_scalar( $_->{_source} );
        $_->{_source}
    } @{ $authors->{hits}{hits} };

    return { authors => \@authors };
}

sub search {
    my ( $self, $query, $from ) = @_;

    my $body = {
        query => {
            bool => {
                should => [
                    {
                        match => {
                            'name.analyzed' =>
                                { query => $query, operator => 'and' }
                        }
                    },
                    {
                        match => {
                            'asciiname.analyzed' =>
                                { query => $query, operator => 'and' }
                        }
                    },
                    { match => { 'pauseid'    => uc($query) } },
                    { match => { 'profile.id' => lc($query) } },
                ]
            }
        },
        size => 10,
        from => $from || 0,
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'author',
        body  => $body,
    );
    return {} unless $ret->{hits}{total};

    my @authors = map {
        single_valued_arrayref_to_scalar( $_->{_source} );
        +{ %{ $_->{_source} }, id => $_->{_id} }
    } @{ $ret->{hits}{hits} };

    return +{
        authors => \@authors,
        took    => $ret->{took},
        total   => $ret->{hits}{total},
    };
}

__PACKAGE__->meta->make_immutable;
1;
