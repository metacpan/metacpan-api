package MetaCPAN::Model::User;

use MetaCPAN::Moose;

use Log::Contextual qw( :log :dlog );
use MooseX::StrictConstructor;

use MetaCPAN::Types qw( Object );

#use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

has es => (
    is       => 'ro',
    isa      => Object,
    handles  => { _run_query => 'search', },
    required => 1,
);

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

1;

