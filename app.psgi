use strict;
use warnings;
use File::Basename ();
my $root_dir;

BEGIN {
    $root_dir = File::Basename::dirname(__FILE__);
}
use lib "$root_dir/lib";

use Config::ZOMG;
use File::Path    ();
use File::Spec    ();
use Log::Log4perl ();
use Path::Tiny qw( path );
use Plack::App::Directory ();
use Plack::App::URLMap    ();

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

    package MetaCPAN::Server::WarnHandler;
    Log::Log4perl->wrapper_register(__PACKAGE__);
    my $logger = Log::Log4perl->get_logger;
    $SIG{__WARN__} = sub { $logger->warn(@_) };
}

use MetaCPAN::Server;

STDERR->autoflush;

# prevent output buffering when in Docker containers (e.g. in docker-compose)
if ( -e "/.dockerenv" and MetaCPAN::Server->log->isa('Catalyst::Log') ) {
    STDOUT->autoflush;
}

my $static
    = Plack::App::Directory->new(
    { root => path( $root_dir, 'root', 'static' ) } )->to_app;

my $urlmap = Plack::App::URLMap->new;
$urlmap->map( '/static' => $static );
$urlmap->map( '/'       => MetaCPAN::Server->app );

return $urlmap->to_app;
