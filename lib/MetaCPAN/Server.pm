package MetaCPAN::Server;

use Moose;

## no critic (Modules::RequireEndWithOne)
use Catalyst qw( +MetaCPAN::Role::Fastly::Catalyst ), '-Log=warn,error,fatal';
use Digest::SHA             ();
use Log::Log4perl::Catalyst ();
use Plack::Builder          qw( builder enable );
use Ref::Util               qw( is_arrayref is_hashref );

extends 'Catalyst';

has api => ( is => 'ro' );

sub clear_stash {
    %{ $_[0]->stash } = ();
}

__PACKAGE__->request_class_traits( [ qw(
    Catalyst::TraitFor::Request::REST
    Catalyst::TraitFor::Request::REST::ForBrowsers
    MetaCPAN::Server::Role::Request
) ] );
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

__PACKAGE__->log( Log::Log4perl::Catalyst->new( undef, autoflush => 1 ) );

__PACKAGE__->setup( qw(
    Static::Simple
    ConfigLoader
    Session
    Session::Store::ElasticSearch
    Session::State::Cookie
    Authentication
) );

sub app {
    my $class = shift;
    builder {
        enable sub {
            my $app = shift;
            sub {
                my ($env) = @_;

                my $request_id = Digest::SHA::sha1_hex( join( "\0",
                    $env->{REMOTE_ADDR}, $env->{REQUEST_URI}, time, $$,
                    rand, ) );
                $env->{'MetaCPAN::Server.request_id'} = $request_id;

                Log::Log4perl::MDC->remove;
                Log::Log4perl::MDC->put( "request_id", $request_id );
                Log::Log4perl::MDC->put( "ip",         $env->{REMOTE_ADDR} );
                Log::Log4perl::MDC->put( "method",  $env->{REMOTE_METHOD} );
                Log::Log4perl::MDC->put( "url",     $env->{REQUEST_URI} );
                Log::Log4perl::MDC->put( "referer", $env->{HTTP_REFERER} );
                Log::Log4perl::MDC->put( "web_request_id",
                    $env->{HTTP_X_METACPAN_REQUEST_ID} )
                    if $env->{HTTP_X_METACPAN_REQUEST_ID};
                $app->($env);
            };
        };

        $class->apply_default_middlewares( $class->psgi_app );
    };
}

# a controller method to read a given parameter key which will be read
# from either the URL (query parameter) or from the (JSON) deserialized
# request body (not both, 'body' parameters take precedence).
# the returned output is an arrayref containing the parameter values.
sub read_param {
    my ( $c, $key, $optional ) = @_;

    my $body_data = $c->req->body_data;
    my $params
        = $body_data
        ? $body_data->{$key}
        : [ $c->req->param($key) ];

    $params = [ $params // () ] unless is_arrayref($params);

    $c->detach( '/bad_request', ["Missing param: $key"] )
        if !$optional && !@$params;

    return $params;
}

# a controller method to either stash given data or detach
# with a not_found message
sub stash_or_detach {
    my ( $c, $data ) = @_;
    ( $data and is_hashref($data) )
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

before perform_purges => sub {
    my ($self) = @_;
    if ( $self->has_surrogate_keys_to_purge ) {
        my $log = $self->log;
        return
            unless $log->is_info;
        $log->info( "CDN Purge: " . join ', ',
            $self->surrogate_keys_to_purge );
    }
};

1;

__END__
