package MetaCPAN::Role::ES;

use Moose::Role;
use MooseX::Types::ElasticSearch qw(:all);

has es => (
    is      => 'ro',
    isa     => ES,
    lazy    => 1,
    coerce  => 1,
    builder => '_build_es',
);

sub _build_es {
    return Search::Elasticsearch->new(
        client => '2_0::Direct',
        ( $ENV{ES} ? ( nodes => [ $ENV{ES} ] ) : () ),
    );
}

sub refresh {
    my ( $self, $name ) = @_;
    $self->es->indices->refresh( index => $name );
}

no Moose::Role;
1;
