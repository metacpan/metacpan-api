package MetaCPAN::Query::Author;

use MetaCPAN::Moose;

use MetaCPAN::Util qw(hit_total);
use Ref::Util      qw( is_arrayref );

with 'MetaCPAN::Query::Role::Common';

sub by_ids {
    my ( $self, $ids ) = @_;

    map {uc} @{$ids};

    my $body = {
        query => { ids => { values => $ids } },
        size  => scalar @{$ids},
    };

    my $authors = $self->es->search(
        index => $self->index_name,
        type  => 'author',
        body  => $body,
    );

    my @authors = map $_->{_source}, @{ $authors->{hits}{hits} };

    return {
        authors => \@authors,
        took    => $authors->{took},
        total   => hit_total($authors),
    };
}

sub by_user {
    my ( $self, $users ) = @_;
    $users = [$users] unless is_arrayref($users);

    my $authors = $self->es->search(
        index => $self->index_name,
        type  => 'author',
        body  => {
            query => { terms => { user => $users } },
            size  => 500,
        }
    );

    my @authors = map $_->{_source}, @{ $authors->{hits}{hits} };

    return {
        authors => \@authors,
        took    => $authors->{took},
        total   => hit_total($authors),
    };
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
                                { query => $query, operator => 'AND' }
                        }
                    },
                    {
                        match => {
                            'asciiname.analyzed' =>
                                { query => $query, operator => 'AND' }
                        }
                    },
                    { match => { 'pauseid'    => uc($query) } },
                    { match => { 'profile.id' => lc($query) } },
                ],
            }
        },
        size => 10,
        from => $from || 0,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'author',
        body  => $body,
    );

    my @authors = map { +{ %{ $_->{_source} }, id => $_->{_id} } }
        @{ $ret->{hits}{hits} };

    return +{
        authors => \@authors,
        took    => $ret->{took},
        total   => hit_total($ret),
    };
}

sub prefix_search {
    my ( $self, $query, $opts ) = @_;
    my $size = $opts->{size} // 500;
    my $from = $opts->{from} // 0;

    my $body = {
        query => {
            prefix => {
                pauseid => $query,
            },
        },
        size => $size,
        from => $from,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'author',
        body  => $body,
    );

    my @authors = map { +{ %{ $_->{_source} }, id => $_->{_id} } }
        @{ $ret->{hits}{hits} };

    return +{
        authors => \@authors,
        took    => $ret->{took},
        total   => hit_total($ret),
    };
}

__PACKAGE__->meta->make_immutable;
1;
