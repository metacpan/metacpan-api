use strict;
use warnings;
use File::Basename ();
my $root_dir;

BEGIN {
    $root_dir = File::Basename::dirname(__FILE__);
}
use lib "$root_dir/lib";

use Config::ZOMG          ();
use File::Path            ();
use File::Spec            ();
use Log::Log4perl         ();
use Path::Tiny            qw( path );
use Plack::App::File      ();
use Plack::App::Directory ();
use Plack::App::URLMap    ();
use Plack::Util           ();

my $dev_mode;
my $config;

BEGIN {
    $dev_mode = $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development';
    $config   = Config::ZOMG->open(
        name => 'MetaCPAN::Server',
        path => $root_dir,
    );

    if ($dev_mode) {
        $ENV{METACPAN_SERVER_DEBUG} = 1;
        if ( !$ENV{EMAIL_SENDER_TRANSPORT} ) {
            $ENV{EMAIL_SENDER_TRANSPORT} = 'Maildir';
            File::Path::mkpath( $ENV{EMAIL_SENDER_TRANSPORT_dir}
                    = "$root_dir/var/tmp/mail" );
        }
    }

    my $log4perl_config
        = File::Spec->rel2abs( $config->{log4perl_file} || 'log4perl.conf',
        $root_dir );
    Log::Log4perl::init($log4perl_config);

    package MetaCPAN::Server::WarnHandler;    ## no critic (Modules::RequireFilenameMatchesPackage)
    Log::Log4perl->wrapper_register(__PACKAGE__);
    my $logger = Log::Log4perl->get_logger;
    $SIG{__WARN__} = sub { $logger->warn(@_) };
}

use MetaCPAN::Server ();

STDERR->autoflush;

# prevent output buffering when in Docker containers (e.g. in docker-compose)
if ( -e "/.dockerenv" and MetaCPAN::Server->log->isa('Catalyst::Log') ) {
    STDOUT->autoflush;
}

sub _add_headers {
    my ( $app, $add_headers ) = @_;
    sub {
        Plack::Util::response_cb(
            $app->(@_),
            sub {
                my $res = shift;
                my ( $status, $headers ) = @$res;
                if ( $status >= 200 && $status < 300 ) {
                    push @$headers, @$add_headers;
                }
                return $res;
            }
        );
    };
}

my $static
    = Plack::App::Directory->new(
    { root => path( $root_dir, 'root', 'static' ) } )->to_app;

my $urlmap = Plack::App::URLMap->new;
$urlmap->map(
    '/favicon.ico' => _add_headers(
        Plack::App::File->new(
            file => path( $root_dir, 'root', 'static', 'favicon.ico' )
        )->to_app,
        [
            'Cache-Control'     => 'public, max-age=' . ( 60 * 60 * 24 ),
            'Surrogate-Control' => 'max-age=' . ( 60 * 60 * 24 * 365 ),
            'Surrogate-Key'     => 'static',
        ],
    )
);
$urlmap->map( '/static' => $static );
if ( $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development' ) {
    $urlmap->map( '/v1' => MetaCPAN::Server->app );
}
$urlmap->map( '/' => MetaCPAN::Server->app );

return $urlmap->to_app;
