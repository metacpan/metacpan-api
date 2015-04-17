use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More skip_all => 'Scripting is disabled';
use URI;

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

    local
        $MetaCPAN::Server::QuerySanitizer::metacpan_scripts{test_script_field}
        = q{doc['author.pauseid'].value.length() * 2};

    test_all_methods(
        {
            query => { match_all => {} },
            script_fields =>
                { pauselen2 => { metacpan_script => 'test_script_field' }, },
            filter => { term => { pauseid => 'RWSTAUNER' } },
        },
        sub {
            my ($req) = shift;

            my $res = $cb->($req);
            is $res->code, 200, $req->method . ' 200 OK'
                or diag explain $res;

            my $json = decode_json_ok($res);

            is_deeply $json->{hits}{hits}->[0]->{fields},
                { pauselen2 => [18] }, 'script_fields via metacpan_script'
                or diag explain $json;
        },
    );
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

my %replacements = (
    prefer_shorter_module_names_100 =>
        qr#\Q_score - doc['documentation'].value.length()/100\E#,

    prefer_shorter_module_names_400 =>
        qr#\Qif(documentation == empty)\E.+\Q.length()/400\E#s,

    score_version_numified => qr#\Qdoc['module.version_numified'].value\E#,

    status_is_latest => qr#\Qdoc['status'].value == 'latest'\E#,

    stupid_script_that_doesnt_exist => undef,
);

while ( my ( $mscript, $re ) = each %replacements ) {
    my $query = filtered_custom_score_hash( metacpan_script => $mscript );

    my $sanitizer = MetaCPAN::Server::QuerySanitizer->new( query => $query, );

    my $cleaned = $sanitizer->query;
    like_if_defined
        delete $cleaned->{query}{filtered}{query}{custom_score}{script},
        $re, "$mscript script replaced";

    is_deeply $cleaned, filtered_custom_score_hash(),
        'metacpan_script removed';

    # try another hash structure
    $query
        = {
        foo => { bar => [ { metacpan_script => $mscript, other => 'val' } ] }
        };

    $cleaned
        = MetaCPAN::Server::QuerySanitizer->new( query => $query )->query;

    like_if_defined delete $cleaned->{foo}{bar}->[0]->{script},
        $re, "$mscript script replaced";
    is_deeply $cleaned, { foo => { bar => [ { other => 'val' } ] } },
        'any hash structure accepts metacpan_script';
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
