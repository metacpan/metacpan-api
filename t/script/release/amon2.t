use Test::Most;
use warnings;
use strict;
use Data::DPath qw(dpath);
use JSON::XS;

use MetaCPAN::Script::Release;

my $script;
{
    local @ARGV =
      ( 'release', 'var/tmp/http/authors/id/T/TO/TOKUHIROM/Amon2-2.26.tar.gz' );
    $script = MetaCPAN::Script::Release->new_with_options;
    $script->run;
}

my $es = $script->es;

done_testing;
