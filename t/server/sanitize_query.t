use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok encode_json );
use Test::More skip_all => 'Scripting is disabled';
use URI ();

sub uri {
    my $uri = URI->new(shift);
    $uri->query_form( {@_} );
    return $uri->as_string;
}

sub like_if_defined {
    my ( $val, $exp, $desc ) = @_;
    defined($exp) ? like( $val, $exp, $desc ) : is( $val, undef, $desc );
}

my $error_message = 'Parameter "script" not allowed';

my %errors = (
    'filter:script' =>
        '{"query":{"match_all":{}},"filter":{"script":{"script":"true"}}}',
    'filtered query custom_score' => {
        filtered => {
            query => {
                custom_score => {
                    query  => { who => 'cares' },
                    script => 'anything',
                },
            },
            filter => { dont => 'care' },
        }
    },
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $desc, $search ) = each %errors ) {
        test_all_methods(
            $search,
            sub {
                my ($req) = shift;
                test_bad_request( $cb, $desc, $search, $req );
            }
        );
    }
};

sub test_all_methods {
    my ( $search, $sub ) = @_;
    $search = encode_json($search) if ref($search) eq 'HASH';

    foreach my $req (
        POST( '/author/_search', Content => $search ),
        GET( uri( '/author/_search', source => $search ) ),
        )
    {
        $sub->($req);
    }
}

sub test_bad_request {
    my ( $cb, $desc, $search, $req ) = @_;
    my $method = $req->method;
    subtest "bad request for $method '$desc'" => sub {
        if ( $method eq 'GET' ) {
            like $req->uri, qr/\?source=%7B%22(query|filtered)%22%3A/,
                'uri has json in querystring';
        }
        else {
            like $req->content, qr/{"(query|filtered)":/, 'body is json';
        }

        ok( my $res = $cb->($req), "$method request" );

        is $res->code, 403, 'Not allowed';

        my $json = decode_json_ok($res)
            or diag explain $res;

        is_deeply $json, { message => "$error_message" },
            "error returned for $desc";
    };
}

hash_key_rejected( script => { script => 'foobar' } );
hash_key_rejected(
    script => { tree => { of => 'many', hashes => { script => 'foobar' } } }
);
hash_key_rejected(
    script => {
        with => { arrays => [ { of => 'hashes' }, { script => 'foobar' } ] }
    }
);

{
    my $hash = filtered_custom_score_hash( hi => 'there' );

    is_deeply delete $hash->{query}{filtered}{query},
        { custom_score => { query => { foo => 'bar' }, hi => 'there' } },
        'remove custom_score hash';

    $hash->{query}{filtered}{fooey} = {};

    is_deeply
        +MetaCPAN::Server::QuerySanitizer->new( query => $hash )->query,
        { query => { filtered => { fooey => {} } }, },
        'test that sanitizing does not autovivify hash keys';
}

done_testing;

sub filtered_custom_score_hash {
    return {
        query => {
            filtered => {
                query => {
                    custom_score => {
                        query => { foo => 'bar' },
                        @_
                    }
                }
            }
        }
    };
}

sub hash_key_rejected {
    my ( $key, $hash ) = @_;
    my $e;
    try {
        MetaCPAN::Server::QuerySanitizer->new( query => $hash )->query;
    }
    catch {
        $e = $_[0];
    };

    if ( defined $e ) {
        like $e, qr/Parameter "$key" not allowed/, "died for bad key '$key'";
    }
    else {
        ok 0, 'error expected but not found';
    }
}
