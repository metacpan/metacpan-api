use strict;
use warnings;

use FindBin;
use lib "$FindBin::RealBin/lib";

if ( $ENV{PLACK_ENV} eq 'development' ) {

    # In development send emails to a directory.
    if ( !$ENV{EMAIL_SENDER_TRANSPORT} ) {
        $ENV{EMAIL_SENDER_TRANSPORT}     = 'Maildir';
        $ENV{EMAIL_SENDER_TRANSPORT_dir} = "$FindBin::RealBin/var/tmp/mail";
    }
}

# The class has the Plack initialization and returns the app.
require MetaCPAN::Server;
