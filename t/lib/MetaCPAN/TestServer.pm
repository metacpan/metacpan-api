package MetaCPAN::TestServer;

use strict;
use warnings;

use CPAN::Repository::Perms;
use MetaCPAN::Script::Author;
use MetaCPAN::Script::Latest;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use MetaCPAN::TestHelpers qw( get_config );
use MetaCPAN::Types qw( Dir HashRef Str );
use Moose;
use Search::Elasticsearch;
use Search::Elasticsearch::TestServer;
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

has _config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
);

has _es_home => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_es_home',
);

has _cpan_dir => (
    is       => 'ro',
    isa      => Dir,
    init_arg => 'cpan_dir',
    coerce   => 1,
    default  => 't/var/tmp/fakecpan',
);

sub _build_config {
    my $self = shift;

    # don't know why get_config is not imported by this point
    my $config = MetaCPAN::TestHelpers::get_config();

    $config->{es}   = $self->es_client;
    $config->{cpan} = $self->_cpan_dir;
    return $config;
}

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

sub put_mappings {
    my $self = shift;

    local @ARGV = qw(mapping --delete);
    ok( MetaCPAN::Script::Mapping->new_with_options( $self->_config )->run,
        'put mapping' );
    $self->wait_for_es();
}

sub index_releases {
    my $self = shift;
    my %args = @_;

    local @ARGV = ( 'release', $self->_cpan_dir, '--children', 0 );
    ok(
        MetaCPAN::Script::Release->new_with_options( %{ $self->_config },
            %args )->run,
        'index releases'
    );
}

sub set_latest {
    my $self = shift;
    local @ARGV = ('latest');
    ok( MetaCPAN::Script::Latest->new_with_options( $self->_config )->run,
        'latest' );
}

sub index_authors {
    my $self = shift;

    local @ARGV = ('author');
    ok( MetaCPAN::Script::Author->new_with_options( $self->_config )->run,
        'index authors' );
}

__PACKAGE__->meta->make_immutable();
1;
