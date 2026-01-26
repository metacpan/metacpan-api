use strict;
use warnings;
use lib 't/lib';

use Test::More;

## no perlimports
use MetaCPAN::Script::Author         ();
use MetaCPAN::Script::Backpan        ();
use MetaCPAN::Script::Backup         ();
use MetaCPAN::Script::Check          ();
use MetaCPAN::Script::Checksum       ();
use MetaCPAN::Script::Contributor    ();
use MetaCPAN::Script::Cover          ();
use MetaCPAN::Script::CPANTestersAPI ();
use MetaCPAN::Script::External       ();
use MetaCPAN::Script::Favorite       ();
use MetaCPAN::Script::First          ();
use MetaCPAN::Script::Latest         ();
use MetaCPAN::Script::Mapping        ();
use MetaCPAN::Script::Mirrors        ();
use MetaCPAN::Script::Package        ();
use MetaCPAN::Script::Permission     ();
use MetaCPAN::Script::Purge          ();
use MetaCPAN::Script::Queue          ();
use MetaCPAN::Script::Release        ();
use MetaCPAN::Script::Restart        ();
use MetaCPAN::Script::River          ();
require MetaCPAN::Script::Role::Contributor;
require MetaCPAN::Script::Role::External::Cygwin;
require MetaCPAN::Script::Role::External::Debian;
use MetaCPAN::Script::Runner   ();
use MetaCPAN::Script::Session  ();
use MetaCPAN::Script::Snapshot ();
use MetaCPAN::Script::Suggest  ();
use MetaCPAN::Script::Tickets  ();
use MetaCPAN::Script::Watcher  ();
## use perlimports

pass 'all loaded Ok';

done_testing();
