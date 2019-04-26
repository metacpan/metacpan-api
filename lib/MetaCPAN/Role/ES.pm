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

no Moose::Role;
1;
