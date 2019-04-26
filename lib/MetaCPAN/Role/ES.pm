package MetaCPAN::Role::ES;

use Moose::Role;
use MooseX::Types::ElasticSearch qw(:all);
use MetaCPAN::Types qw( Str );

has es => (
    is      => 'ro',
    isa     => ES,
    lazy    => 1,
    coerce  => 1,
    builder => '_build_es',
);

has index_name => (
    is      => 'ro',
    isa     => Str,
    default => 'cpan',
);

sub _build_es {
    return Search::Elasticsearch->new(
        client => '2_0::Direct',
        ( $ENV{ES} ? ( nodes => [ $ENV{ES} ] ) : () ),
    );
}

sub refresh {
    my ( $self, $name ) = @_;
    $name //= $self->index_name;
    $self->es->indices->refresh( index => $name );
}

sub delete_all_ids {
    my ( $self, $type, $index ) = @_;
    $index //= $self->index_name;

    # collect all ids in type
    my @ids;
    my $scroll = $self->es->scroll_helper(
        {
            size   => 1000,
            scroll => '1m',
            index  => $index,
            type   => $type,
            fields => [],
        }
    );
    while ( my $record = $scroll->next ) {
        push @ids, $record->{_id};
    }

    # delete all ids
    my $bulk = $self->es->bulk_helper(
        index     => $index,
        type      => $type,
        max_count => 500,
    );
    $bulk->delete_ids(@ids);
    $bulk->flush;
}

no Moose::Role;
1;
