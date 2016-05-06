package MetaCPAN::TestServer;

use MetaCPAN::Moose;

use CPAN::Repository::Perms;
use MetaCPAN::Script::Author;
use MetaCPAN::Script::CPANTesters ();
use MetaCPAN::Script::Latest;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use MetaCPAN::TestHelpers qw( get_config fakecpan_dir );
use MetaCPAN::Types qw( Dir HashRef Str );
use Search::Elasticsearch;
use Search::Elasticsearch::TestServer;
use Test::More;
use Try::Tiny qw( catch try );

has es_client => (
    is      => 'ro',
    isa     => 'Search::Elasticsearch::Client::2_0::Direct',
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
    default  => sub { fakecpan_dir() },
);

sub setup {
    my $self = shift;

    $self->es_client;
    $self->put_mappings;
}

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

=head2 _build_es_server

This starts an Elastisearch server on the fly.  It should only be called if the
ES env var contains a path to Elasticsearch.  If the variable contains a port
number then we'll assume the server has already been started on this port.

=cut

sub _build_es_server {
    my $self = shift;

    my $server = Search::Elasticsearch::TestServer->new(
        conf      => [ 'cluster.name' => 'metacpan-test' ],
        es_home   => $self->_es_home,
        es_port   => 9700,
        http_port => 9900,
        instances => 1,
    );

    diag 'Connecting to Elasticsearch on ' . $self->_es_home;

    try {
        $ENV{ES} = $server->start->[0];
    }
    catch {
        diag(<<"EOF");
Failed to connect to the Elasticsearch test instance on ${\$self->_es_home}.
Did you start one up? See https://github.com/CPAN-API/cpan-api/wiki/Installation
for more information.
Error: $_
EOF
        BAIL_OUT('Test environment not set up properly');
    };

    diag( 'Connected to the Elasticsearch test instance on '
            . $self->_es_home );
}

sub _build_es_client {
    my $self = shift;

    # Don't try to start a test server if we've been passed the port number of
    # a running instance.

    $self->es_server unless $self->_es_home =~ m{:};

    my $es = Search::Elasticsearch->new(
        nodes => $self->_es_home,
        ( $ENV{ES_TRACE} ? ( trace_to => [ 'File', 'es.log' ] ) : () )
    );

    ok( $es, 'got ElasticSearch object' );

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

    local @ARGV = ( 'release', $ENV{MC_RELEASE} ? $ENV{MC_RELEASE} : $self->_cpan_dir );
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

# Right now this test requires you to have an internet connection.  If we can
# get a sample db then we can run this with the '--skip-download' option.

sub index_cpantesters {
    my $self = shift;

    local @ARGV = ( 'cpantesters', '--force-refresh' );
    ok(
        MetaCPAN::Script::CPANTesters->new_with_options( $self->_config )
            ->run,
        'index authors'
    );
}

__PACKAGE__->meta->make_immutable;
1;
