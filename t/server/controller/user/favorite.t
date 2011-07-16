
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

test_psgi app, sub {
    my $cb = shift;
    ok( my $res = $cb->(
            POST '/user/favorite?access_token=testing',
            Content => encode_json(
                {   distribution => 'Moose',
                    release      => 'Moose-1.10',
                    author       => 'DOY'
                }
            )
        ),
        "POST favorite"
    );
    is($res->code, 201, 'status created');
    ok(my $location = $res->header('location'), "location header set");
    ok($res = $cb->( GET $location ), "GET $location");
    is($res->code, 200, 'found');
    my $json = decode_json($res->content);
    (my $id = $location) =~ s/^.*\///;
    is($json->{user}, 'MO', 'user is mo');
    ok($res = $cb->( DELETE "/user/favorite/$id?access_token=testing" ), "DELETE $location");
    is($res->code, 200, 'status ok');
    ok($res = $cb->( GET "$location?access_token=testing" ), "GET $location");
    is($res->code, 404, 'not found');
    
    
};

done_testing;
