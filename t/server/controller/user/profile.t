use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       qw( encode_json );
use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use Test::More;

use HTTP::Request::Common ();

test_psgi app, sub {
    my $cb = shift;

    ok( my $res = $cb->( GET '/user/profile?access_token=testing' ),
        'GET /user/profile' );
    is( $res->code, 200, 'code 200' );
    my $profile = decode_json_ok($res);

   # An author whose name is already ASCII has an empty/null asciiname. Saving
   # the profile form sends "asciiname": null. This must not be rejected with
   # "asciiname is required": asciiname is required => 1 but has a default, so
   # an absent value is filled in at construction time.
    my $put = HTTP::Request::Common::PUT(
        '/user/profile?access_token=testing',
        Content_Type => 'application/json',
        Content      => encode_json( {
            name      => 'Moritz Onken',
            asciiname => undef,
            website   => ['http://metacpan.org/'],
            email     => ['onken@netcubed.de'],
            city      => 'Karlsruhe',
            region    => 'BW',
            country   => 'DE',
        } ),
    );

    ok( $res = $cb->($put), 'PUT /user/profile with null asciiname' );
    is( $res->code, 201, 'profile saved (status created)' )
        or diag( $res->content );

    my $saved = decode_json_ok($res);
    is( $saved->{asciiname} // q{},
        q{}, 'asciiname is empty (default applied), not rejected' );
};

done_testing;
