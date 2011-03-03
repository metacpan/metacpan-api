use Test::Most;
use strict;
use warnings;
use ElasticSearch::Document::Types qw(:all);

is_deeply(Location->coerce('12,13'), [13,12]);
is_deeply(Location->coerce({ lat => 12, lon => 13 }), [13,12]);
is_deeply(Location->coerce({ latitude => 12, longitude => 13 }), [13,12]);

is(ESDateTime->coerce(10)->iso8601, '1970-01-01T00:00:10');
is(ESDateTime->coerce('1970-01-01T00:00:20')->iso8601, '1970-01-01T00:00:20');
is(ESDateTime->coerce('1970-01-01')->iso8601, '1970-01-01T00:00:00');

done_testing;