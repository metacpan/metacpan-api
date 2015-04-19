package MetaCPAN::TestServer;

use strict;
use warnings;

use MetaCPAN::Types qw( Str );
use Moose;
use Test::More;

has es_client => (
    is      => 'ro',
    isa     => 'Search::Elasticsearch::Client::Direct',
    lazy    => 1,
    builder => '_build_es_client',
);

has es_server => (
    is      => 'ro',
    isa     => 'Search::Elasticsearch::TestServer',
    lazy    => 1,
    builder => '_build_es_server',
);

has _es_home => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_es_home',
);

sub _build_es_home {
    my $self = shift;

    my $es_home = $ENV{ES};

    if ( !$es_home ) {
        my $es_home = $ENV{ES_HOME} or die <<'USAGE';
Please set $ENV{ES} to a running instance of Elasticsearch, eg
'localhost:9200' or set $ENV{ES_HOME} to the directory containing
Elasticsearch
USAGE
    }

    return $es_home;
}

sub _build_es_server {
    my $self = shift;

    my $server = Search::Elasticsearch::TestServer->new(
        es_home        => $self->_es_home,
        http_port      => 9900,
        es_port        => 9700,
        instances      => 1,
        'cluster.name' => 'metacpan-test',
    );

    $ENV{ES} = $server->start->[0];

    diag 'Connecting to Elasticsearch on ' . $self->_es_home;
}

sub _build_es_client {
    my $self = shift;

    my $es = Search::Elasticsearch->new(
        nodes => $self->_es_home,
        ( $ENV{ES_TRACE} ? ( trace_to => [ 'File', 'es.log' ] ) : () )
    );

    ok( $es, 'got ElasticSearch object' );

    my $host = $self->_es_home;

    ok( !$@, "Connected to the Elasticsearch test instance on $host" )
        or do {
        diag(<<EOF);
Failed to connect to the Elasticsearch test instance on $host.
Did you start one up? See https://github.com/CPAN-API/cpan-api/wiki/Installation
for more information.
EOF

        BAIL_OUT('Test environment not set up properly');
        };

    note( Test::More::explain( { 'Elasticsearch info' => $es->info } ) );

    return $es;
}

sub wait_for_es {
    my $self = shift;

    sleep $_[0] if $_[0];

    $self->es_client->cluster->health(
        wait_for_status => 'yellow',
        timeout         => '30s'
    );
    $self->es_client->indices->refresh;
}

__PACKAGE__->meta->make_immutable();
1;
