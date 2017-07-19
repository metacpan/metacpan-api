package MetaCPAN::Server;

use Moose;

## no critic (Modules::RequireEndWithOne)
use Catalyst qw( +MetaCPAN::Role::Fastly::Catalyst );

use CatalystX::RoleApplicator;
use File::Temp qw( tempdir );
use Plack::Middleware::ReverseProxy;
use Plack::Middleware::ServerStatus::Lite;
use Ref::Util qw( is_arrayref );

extends 'Catalyst';

has api => ( is => 'ro' );

sub clear_stash {
    %{ $_[0]->stash } = ();
}

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
    ## no critic  ValuesAndExpressions::ProhibitMagicNumbers
    'Plugin::Session' => { expires => 2**30 },
    ## use critic

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
    'Controller::Login::Google' => {
        consumer_key =>
            '265904441292-5k4rhagfcddsv4g5jfdk93eh8tugrp13.apps.googleusercontent.com',
        consumer_secret => 'kd3nmULLpTIsR2P89SWCxE8D',
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
        Session
        Session::Store::ElasticSearch
        Session::State::Cookie
        Authentication
        OAuth2::Provider
        )
);

my $app = __PACKAGE__->apply_default_middlewares( __PACKAGE__->psgi_app );

# Using an ES client against the API requires an index (/v0).
# In production nginx handles this.
if ( $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development' ) {
    require Plack::Middleware::Rewrite;
    $app = Plack::Middleware::Rewrite->wrap( $app,
        rules => sub {s{^/?v\d+/}{}} );
}

# Should this be `unless ( $ENV{HARNESS_ACTIVE} ) {` ?
{
    my $scoreboard
        = $ENV{HARNESS_ACTIVE}
        ? tempdir( CLEANUP => 1 )
        : __PACKAGE__->path_to(qw(var tmp scoreboard));

   # This may be a File object if it doesn't exist so change it, then make it.
    my $dir = Path::Class::Dir->new(
        ref $scoreboard ? $scoreboard->stringify : $scoreboard );
    $dir->mkpath unless -d $dir;

    Plack::Middleware::ServerStatus::Lite->wrap(
        $app,
        path       => '/server-status',
        allow      => ['127.0.0.1'],
        scoreboard => $scoreboard,
    );
}

# prevent output buffering when in Docker containers (e.g. in docker-compose)
if ( -e "/.dockerenv" and __PACKAGE__->log->isa('Catalyst::Log') ) {
    STDERR->autoflush;
    STDOUT->autoflush;
}

sub to_app {
    return $app;
}

# a controller method to read a given parameter key which will be read
# from either the URL (query parameter) or from the (JSON) deserialized
# request body (not both, 'body' parameters take precedence).
# the returned output is an arrayref containing the parameter values.
sub read_param {
    my ( $c, $key ) = @_;

    my $body_data = $c->req->body_data;
    my $params
        = $body_data
        ? $body_data->{$key}
        : [ $c->req->param($key) ];

    $params = [$params] unless is_arrayref($params);

    $c->detach( '/bad_request', ["Missing param: $key"] )
        unless $params and @{$params};

    return $params;
}

# a controller method to either stash given data or detach
# with a not_found message
sub stash_or_detach {
    my ( $c, $data ) = @_;
    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

1;

__END__
