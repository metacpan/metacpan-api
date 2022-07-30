package MetaCPAN::TestServer;

use MetaCPAN::Moose;

use Cpanel::JSON::XS qw( decode_json encode_json );
use MetaCPAN::DarkPAN                ();
use MetaCPAN::Script::Author         ();
use MetaCPAN::Script::Cover          ();
use MetaCPAN::Script::CPANTestersAPI ();
use MetaCPAN::Script::Favorite       ();
use MetaCPAN::Script::First          ();
use MetaCPAN::Script::Latest         ();
use MetaCPAN::Script::Mapping        ();
use MetaCPAN::Script::Mapping::Cover ();
use MetaCPAN::Script::Mirrors        ();
use MetaCPAN::Script::Package        ();
use MetaCPAN::Script::Permission     ();
use MetaCPAN::Script::Release        ();
use MetaCPAN::Script::Runner         ();
use MetaCPAN::Server                 ();
use MetaCPAN::TestHelpers qw( fakecpan_dir );
use MetaCPAN::Types::TypeTiny qw( Path HashRef Str );
use Search::Elasticsearch;
use Search::Elasticsearch::TestServer;
use Test::More;
use Try::Tiny qw( catch try );

has es_client => (
    is      => 'ro',
    does    => 'Search::Elasticsearch::Role::Client',
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
    isa      => Path,
    init_arg => 'cpan_dir',
    coerce   => 1,
    default  => sub { fakecpan_dir() },
);

sub setup {
    my $self = shift;

    $self->es_client;

    # Run the Delete Index Tests before mapping deployment
    $self->test_delete_mappings;

    # Deploy project mappings
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

    my $es_home = $ENV{ES_TEST};

    if ( !$es_home ) {
        my $es_home = $ENV{ES_HOME} or die <<'USAGE';
Please set ${ES_TEST} to a running instance of Elasticsearch, eg
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
        $ENV{ES_TEST} = $server->start->[0];
    }
    catch {
        diag(<<"EOF");
Failed to connect to the Elasticsearch test instance on ${\$self->_es_home}.
Did you start one up? See https://github.com/metacpan/metacpan-api/wiki/Installation
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

sub check_mappings {
    my $self           = $_[0];
    my %hshtestindices = (
        'cover'       => 'yellow',
        'cpan_v1_01'  => 'yellow',
        'contributor' => 'yellow',
        'user'        => 'yellow'
    );
    my %hshtestaliases = ( 'cpan' => 'cpan_v1_01' );

    local @ARGV = qw(mapping --show_cluster_info);

    my $mapping
        = MetaCPAN::Script::Mapping->new_with_options( $self->_config );

    ok( $mapping->run, 'show cluster info' );

    note(
        Test::More::explain(
            { 'indices_info' => \%{ $mapping->indices_info } }
        )
    );
    note(
        Test::More::explain(
            { 'aliases_info' => \%{ $mapping->aliases_info } }
        )
    );

    subtest 'only configured indices' => sub {
        ok( defined $hshtestindices{$_}, "indice '$_' is configured" )
            foreach ( keys %{ $mapping->indices_info } );
    };
    subtest 'verify index health' => sub {
        foreach ( keys %hshtestindices ) {
            ok( defined $mapping->indices_info->{$_},
                "indice '$_' was created" );
            is( $mapping->indices_info->{$_}->{'health'},
                $hshtestindices{$_},
                "indice '$_' correct state '$hshtestindices{$_}'" );
        }
    };
    subtest 'verify aliases' => sub {
        foreach ( keys %hshtestaliases ) {
            ok( defined $mapping->aliases_info->{$_},
                "alias '$_' was created" );
            is( $mapping->aliases_info->{$_}->{'index'},
                $hshtestaliases{$_},
                "alias '$_' correctly assigned to '$hshtestaliases{$_}'" );
        }
    };
}

sub put_mappings {
    my $self = shift;

    local @ARGV = qw(mapping --delete);
    ok( MetaCPAN::Script::Mapping->new_with_options( $self->_config )->run,
        'put mapping' );
    $self->check_mappings;
    $self->wait_for_es();
}

sub index_releases {
    my $self = shift;
    my %args = @_;

    local @ARGV = ( 'release',
        $ENV{MC_RELEASE} ? $ENV{MC_RELEASE} : $self->_cpan_dir );
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

sub set_first {
    my $self = shift;
    local @ARGV = ('first');
    ok( MetaCPAN::Script::First->new_with_options( $self->_config )->run,
        'first' );
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

    local @ARGV = ('cpantestersapi');
    ok(
        MetaCPAN::Script::CPANTestersAPI->new_with_options( $self->_config )
            ->run,
        'index cpantesters'
    );
}

sub index_mirrors {
    my $self = shift;

    local @ARGV = ('mirrors');
    ok( MetaCPAN::Script::Mirrors->new_with_options( $self->_config )->run,
        'index mirrors' );
}

sub index_cover {
    my $self = shift;

    local @ARGV = ( 'cover', '--json_file', 't/var/cover.json' );
    ok( MetaCPAN::Script::Cover->new_with_options( $self->_config )->run,
        'index cover' );
}

sub index_permissions {
    my $self = shift;

    ok(
        MetaCPAN::Script::Permission->new_with_options(
            %{ $self->_config },

            # Eventually maybe move this to use the DarkPAN 06perms
            #cpan => MetaCPAN::DarkPAN->new->base_dir,
        )->run,
        'index permissions'
    );
}

sub index_packages {
    my $self = shift;

    ok(
        MetaCPAN::Script::Package->new_with_options(
            %{ $self->_config },

            # Eventually maybe move this to use the DarkPAN 06perms
            #cpan => MetaCPAN::DarkPAN->new->base_dir,
        )->run,
        'index packages'
    );
}

sub index_favorite {
    my $self = shift;

    ok(
        MetaCPAN::Script::Favorite->new_with_options(
            %{ $self->_config },

            # Eventually maybe move this to use the DarkPAN 06perms
            #cpan => MetaCPAN::DarkPAN->new->base_dir,
        )->run,
        'index favorite'
    );
}

sub prepare_user_test_data {
    my $self = shift;
    ok(
        my $user = MetaCPAN::Server->model('User::Account')->put(
            {
                access_token =>
                    [ { client => 'testing', token => 'testing' } ]
            }
        ),
        'prepare user'
    );
    ok( $user->add_identity( { name => 'pause', key => 'MO' } ),
        'add pause identity' );
    ok( $user->put( { refresh => 1 } ), 'put user' );

    ok(
        MetaCPAN::Server->model('User::Account')->put(
            { access_token => [ { client => 'testing', token => 'bot' } ] },
            { refresh      => 1 }
        ),
        'put bot user'
    );
}

sub test_mappings {
    my $self = $_[0];

    $self->test_index_missing;
    $self->test_field_mismatch;
}

sub test_index_missing {
    my $self = $_[0];

    subtest 'missing index' => sub {
        my $scoverindexjson = MetaCPAN::Script::Mapping::Cover::mapping;

        subtest 'delete cover index' => sub {
            local @ARGV = qw(mapping --delete_index cover);
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "deletion 'cover' succeeds" );
            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
        };
        subtest 'mapping verification fails' => sub {
            local @ARGV = qw(mapping --verify);
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            is( $mapping->run, 0, "verification execution fails" );
            is( $mapping->exit_code, 1,
                "Exit Code '1' - Verification Error" );
        };
        subtest 're-create cover index' => sub {
            local @ARGV = (
                'mapping', '--create_index',
                'cover',   '--patch_mapping',
                qq({ "cover": $scoverindexjson })
            );
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "creation 'cover' succeeds" );
            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
        };
    };
}

sub test_field_mismatch {
    my $self = $_[0];

    subtest 'field mismatch' => sub {
        my $sfieldjson = q({
	        "properties" : {
            "version" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
            }
	        }
	      });
        my $sfieldchangejson = q({
	        "properties" : {
            "version" : {
              "ignore_above" : 1024,
              "index" : "not_analyzed",
              "type" : "string"
            }
	        }
	      });

        subtest 'mapping change field' => sub {
            local @ARGV = (
                'mapping', '--update_index',
                'cover',   '--patch_mapping',
                qq({ "cover": $sfieldchangejson })
            );
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "change 'cover' succeeds" );

            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
        };
        subtest 'field verification fails' => sub {
            local @ARGV = qw(mapping --verify);
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            is( $mapping->run, 0, "verification fails" );
            is( $mapping->exit_code, 1,
                "Exit Code '1' - Verification Error" );
        };
        subtest 'mapping re-establish field' => sub {
            local @ARGV = (
                'mapping', '--update_index',
                'cover',   '--patch_mapping',
                qq({ "cover": $sfieldjson })
            );
            my $mapping
                = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "re-establish 'cover' succeeds" );
            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
        };
    };
}

sub test_delete_mappings {
    my $self = $_[0];

    $self->test_delete_fails;
    $self->test_delete_all;
}

sub test_delete_fails {
    my $self = $_[0];

    my $iexitcode;
    my $irunok;

    subtest 'delete all not permitted' => sub {

        # mapping script - delete indices
        {
            local @ARGV = qw(mapping --delete --all);
            local %ENV  = (%ENV);

            delete $ENV{'PLACK_ENV'};
            delete $ENV{'MOJO_MODE'};

            $irunok    = MetaCPAN::Script::Runner::run;
            $iexitcode = $MetaCPAN::Script::Runner::EXIT_CODE;
        }

        ok( !$irunok, "delete all fails" );
        is( $iexitcode, 1, "Exit Code '1' - Permission Error" );
    };
}

sub test_delete_all {
    my $self = $_[0];

    subtest 'delete all deletes unknown index' => sub {
        subtest 'create index' => sub {
            my $smockindexjson = q({
            	"mock_index": {
					      "properties": {
					          "mock_field" : {
					            "type" : "string",
					            "index" : "not_analyzed",
					            "ignore_above" : 2048
					          }
					        }
					      }
					    });

            local @ARGV = (
                'mapping',    '--create_index',
                'mock_index', '--patch_mapping',
                $smockindexjson
            );

            ok( MetaCPAN::Script::Runner::run,
                "creation 'mock_index' succeeds"
            );
            is( $MetaCPAN::Script::Runner::EXIT_CODE,
                0, "Exit Code '0' - No Error" );
        };
        subtest 'info shows unknonwn index' => sub {
            local @ARGV = ( 'mapping', '--show_cluster_info' );
            my $mapping = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "show info succeeds" );
            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );

            ok( defined $mapping->indices_info, 'Index Info built' );
            ok( defined $mapping->indices_info->{'mock_index'},
                'Unknown Index printed' );
        };
        subtest 'delete all succeeds' => sub {
            local @ARGV = qw(mapping --delete --all);

            ok( MetaCPAN::Script::Runner::run, "delete all succeeds" );
            is( $MetaCPAN::Script::Runner::EXIT_CODE,
                0, "Exit Code '0' - No Error" );
        };
        subtest 'info does not show unknown index' => sub {
            local @ARGV = ( 'mapping', '--show_cluster_info' );
            my $mapping = MetaCPAN::Script::Mapping->new_with_options(
                $self->_config );

            ok( $mapping->run, "show info succeeds" );
            is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );

            ok( defined $mapping->indices_info, 'Index Info built' );
            ok( !defined $mapping->indices_info->{'mock_index'},
                'Unknown Index printed' );
        };
    };
}

__PACKAGE__->meta->make_immutable;
1;
