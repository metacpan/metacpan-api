use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::Author;

my @errors = MetaCPAN::Document::Author->validate(
    { perlmongers => { name => 'foo.pm' } } );

ok( !( grep { $_->{field} eq 'perlmongers' } @errors ), 'perlmongers ok' );

done_testing;
