package MetaCPAN::Server;

use Moose;
extends 'Catalyst';
use CatalystX::RoleApplicator;
use Plack::Middleware::ReverseProxy;
use Plack::Middleware::ServerStatus::Lite;

use FindBin;
use lib "$FindBin::RealBin/../";

has api => ( is => 'ro' );
has '+stash' => ( clearer => 'clear_stash' );

__PACKAGE__->apply_request_class_roles(
    qw(
        Catalyst::TraitFor::Request::REST
        Catalyst::TraitFor::Request::REST::ForBrowsers
        MetaCPAN::Server::Role::Request
        )
);
__PACKAGE__->config(
    encoding           => 'UTF-8',
    default_view       => 'JSON',
    'OAuth2::Provider' => {
        login => '/login/index',

        # metacpan.org client is set in metacpan_server_local.conf
        clients => {
            'metacpan.dev' => {
                secret       => 'ClearAirTurbulence',
                redirect_uri => ['http://localhost:5001/login'],
            }
        }
    },
    'Plugin::Session' => { expires => 2**30 },

    # those are for development only. The actual keys are set in
    # metacpan_server_local.conf
    'Controller::Login::Facebook' => {
        consumer_key    => '120778921346364',
        consumer_secret => '3e96474c994f78bbb5fcc836ddee0e09',
    },
    'Controller::Login::GitHub' => {
        consumer_key    => 'bec8ecb39a9fc5935d0e',
        consumer_secret => 'ec32cb6699836554596306616e11568bb8b2101b',
    },
    'Controller::Login::Twitter' => {
        consumer_key    => 'NP647X3WewESJVg19Qelxg',
        consumer_secret => 'MrLQXWHXJsGo9owGX49D6oLnyYoxCOvPoy9TZE5Q',
    },
    'Plugin::Authentication' => {
        default => {
            credential => {
                class         => 'Password',
                password_type => 'none',
            },
            store => { class => 'Proxy', }
        },
    }
);
__PACKAGE__->setup(
    qw(
        Static::Simple
        ConfigLoader
        Unicode::Encoding
        Session
        Session::Store::ElasticSearch
        Session::State::Cookie
        Authentication
        OAuth2::Provider
        )
);

my $app = Plack::Middleware::ReverseProxy->wrap(
    sub {
        __PACKAGE__->run(@_);
    }
);

Plack::Middleware::ServerStatus::Lite->wrap(
   $app,
   path       => '/server-status',
   allow      => ['127.0.0.1'],
   scoreboard => __PACKAGE__->path_to(qw(var tmp scoreboard)),
);
