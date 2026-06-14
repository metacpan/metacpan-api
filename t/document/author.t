use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Document::Author ();
use Test::More;

my @errors = MetaCPAN::Document::Author->validate(
    { perlmongers => { name => 'foo.pm' } } );

ok( !( grep { $_->{field} eq 'perlmongers' } @errors ), 'perlmongers ok' );

# asciiname is required => 1 but has a default => q{}, so an absent asciiname
# must not be reported as missing (the default satisfies the requirement).
ok(
    !( grep { $_->{field} eq 'asciiname' } @errors ),
    'absent asciiname not reported as required'
);

done_testing;
