use strict;
use warnings;

use FindBin;
use lib "$FindBin::RealBin/lib";
use Catalyst::Middleware::Stash 'stash';
use MetaCPAN::Server;

if ( $ENV{PLACK_ENV} eq 'development' ) {

    # In development send emails to a directory.
    if ( !$ENV{EMAIL_SENDER_TRANSPORT} ) {
        $ENV{EMAIL_SENDER_TRANSPORT}     = 'Maildir';
        $ENV{EMAIL_SENDER_TRANSPORT_dir} = "$FindBin::RealBin/var/tmp/mail";
    }
}

MetaCPAN::Server->to_app;

