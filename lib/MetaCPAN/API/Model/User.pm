package MetaCPAN::API::Model::User;

use MetaCPAN::Moose;

with 'MetaCPAN::API::Model::Role::ES';

sub lookup {
    my ( $self, $name, $key ) = @_;

    my $query = {
        bool => {
            must => [
                { term => { 'identity.name' => $name } },
                { term => { 'identity.key'  => $key } },
            ]
        }
    };

    my $res = $self->_run_query(
        index       => 'user',
        type        => 'account',
        body        => { query => $query },
        search_type => 'dfs_query_then_fetch',
    );

    return $res->{hits}{hits}[0]{_source};
}

__PACKAGE__->meta->make_immutable;

1;

