use strict;
use warnings;

use MetaCPAN::Server::Test;
use Cpanel::JSON::XS qw( decode_json );
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    my $module_name = 'CPAN::Test::Dummy::Perl5::VersionBump::Stay';
    ok( my $res = $cb->( GET "/permission/$module_name" ),
        "GET $module_name" );
    is( $res->code, 200, '200 OK' );

    is_deeply(
        decode_json( $res->content ),
        { module_name => $module_name, owner => 'MIYAGAWA', },
        'Owned by MIYAGAWA'
    );
};

done_testing;
