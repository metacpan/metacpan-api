use strict;
use warnings;
use lib 't/lib';

# USE `bin/prove_live` to run this
# READ the README.txt in this dir

use MetaCPAN::Query::Search ();
use MetaCPAN::TestServer    ();
use Test::More;

# Just use this to get an es object.
my $server = MetaCPAN::TestServer->new;
my $search = MetaCPAN::Query::Search->new( es => $server->es_client );

my %tests = (
    'anyevent http'        => 'AnyEvent::HTTP',
    'anyevent'             => 'AnyEvent',
    'AnyEvent'             => 'AnyEvent',
    'dbi'                  => 'DBI',
    'dbix class resultset' => 'DBIx::Class::ResultSet',
    'DBIx::Class'          => 'DBIx::Class',
    'Dist::Zilla'          => 'Dist::Zilla',
    'HTML::Element'        => 'HTML::Element',
    'HTML::TokeParser'     => 'HTML::TokeParser',
    'net dns'              => 'Net::DNS',
    'net::amazon::s3'      => 'Net::Amazon::S3',
    'Perl::Critic'         => 'Perl::Critic',
);

for my $q ( sort keys %tests ) {
    my $match       = $tests{$q};
    my $returned    = $search->search_web($q);
    my $first_match = $returned->{results}->[0]->[0];

    is( $first_match->{documentation},
        $match, "Search for ${q} matched ${match}" );

    #    or diag Dumper($first_match);
}

done_testing();
