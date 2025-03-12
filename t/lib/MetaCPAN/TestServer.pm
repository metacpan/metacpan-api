package MetaCPAN::TestServer;

use MetaCPAN::Moose;

use Cpanel::JSON::XS                 qw( encode_json );
use MetaCPAN::ESConfig               qw( es_config );
use MetaCPAN::Script::Author         ();
use MetaCPAN::Script::Cover          ();
use MetaCPAN::Script::CPANTestersAPI ();
use MetaCPAN::Script::Favorite       ();
use MetaCPAN::Script::First          ();
use MetaCPAN::Script::Latest         ();
use MetaCPAN::Script::Mapping        ();
use MetaCPAN::Script::Mirrors        ();
use MetaCPAN::Script::Package        ();
use MetaCPAN::Script::Permission     ();
use MetaCPAN::Script::Release        ();
use MetaCPAN::Server                 ();
use MetaCPAN::Server::Config         ();
use MetaCPAN::TestHelpers            qw( fakecpan_dir );
use MetaCPAN::Types::TypeTiny        qw( HashRef Path );
use MetaCPAN::Util                   qw( true false );
use MooseX::Types::ElasticSearch     qw( ES );
use Test::More;

has es_client => (
    is      => 'ro',
    isa     => ES,
    coerce  => 1,
    lazy    => 1,
    builder => '_build_es_client',
);

has _config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
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

sub _build_es_client {
    my $self = shift;

    my $es = ES->assert_coerce(
        MetaCPAN::Server::Config::config()->{elasticsearch_servers}, );

    ok( $es, 'got Search::Elasticsearch object' );

    note( Test::More::explain( { 'Elasticsearch info' => $es->info } ) );

    return $es;
}

sub wait_for_es {
    my $self = shift;

    $self->es_client->cluster->health(
        wait_for_status => 'yellow',
        timeout         => '30s'
    );
    $self->es_client->indices->refresh;
}

sub check_mappings {
    my $self    = $_[0];
    my %indices = ( map +( $_ => 'yellow' ), @{ es_config->all_indexes } );

    local @ARGV = qw(mapping --show_cluster_info);

    my $mapping
        = MetaCPAN::Script::Mapping->new_with_options( $self->_config );

    ok( $mapping->run, 'show cluster info' );

    note( Test::More::explain(
        { 'indices_info' => \%{ $mapping->indices_info } }
    ) );

    subtest 'only configured indices' => sub {
        ok( defined $indices{$_}, "indice '$_' is configured" )
            foreach ( keys %{ $mapping->indices_info } );
    };
    subtest 'verify index health' => sub {
        foreach ( keys %indices ) {
            ok( defined $mapping->indices_info->{$_},
                "index '$_' was created" );
            is( $mapping->indices_info->{$_}->{'health'},
                $indices{$_}, "index '$_' correct state '$indices{$_}'" );
        }
    };
}

sub put_mappings {
    my $self = shift;

    local @ARGV = qw(mapping --delete --all);
    ok( MetaCPAN::Script::Mapping->new_with_options( $self->_config )->run,
        'put mapping' );
    $self->check_mappings;
    $self->wait_for_es;
}

sub index_releases {
    my $self = shift;
    my %args = @_;

    local @ARGV = (
        'release', $ENV{MC_RELEASE} ? $ENV{MC_RELEASE} : $self->_cpan_dir
    );
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
        my $user = MetaCPAN::Server->model('ESModel')->doc('account')->put( {
            access_token => [ { client => 'testing', token => 'testing' } ]
        } ),
        'prepare user'
    );
    ok( $user->add_identity( { name => 'pause', key => 'MO' } ),
        'add pause identity' );
    ok( $user->put( { refresh => true } ), 'put user' );

    ok(
        MetaCPAN::Server->model('ESModel')->doc('account')->put(
            { access_token => [ { client => 'testing', token => 'bot' } ] },
            { refresh      => true }
        ),
        'put bot user'
    );
}

__PACKAGE__->meta->make_immutable;
1;
