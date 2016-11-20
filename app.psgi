use strict;
use warnings;

use File::Basename;
use Config::JFDI;
use Log::Log4perl;
use File::Spec;
use File::Path ();

my $root_dir;
my $dev_mode;
my $config;

BEGIN {
    $root_dir = File::Basename::dirname(__FILE__);
    $dev_mode = $ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development';
    $config   = Config::JFDI->new(
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

    my $log4perl_config = File::Spec->rel2abs( $config->get->{log4perl_file}
            || 'log4perl.conf', $root_dir );
    Log::Log4perl::init($log4perl_config);

    package MetaCPAN::Server::WarnHandler;
    Log::Log4perl->wrapper_register(__PACKAGE__);
    my $logger = Log::Log4perl->get_logger;
    $SIG{__WARN__} = sub { $logger->warn(@_) };
}

use lib "$root_dir/lib";

use Catalyst::Middleware::Stash 'stash';
use MetaCPAN::Server;

MetaCPAN::Server->to_app;
