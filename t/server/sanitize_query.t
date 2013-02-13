use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my $error_message = 'Parameter "script" not allowed';

my %errors = (
    'filter:script' =>
        '{"query":{"match_all":{}},"filter":{"script":{"script":"true"}}}',
    'filtered query custom_score' =>
        { filtered => {
            query => {
                custom_score => {
                    query => { who => 'cares' },
                    script => "anything",
                },
            },
            filter => { dont => 'care' },
        } },
);

test_psgi app, sub {
    my $cb = shift;
    while( my ($desc, $search) = each %errors ){
        $search = encode_json($search) if ref($search) eq 'HASH';

        ok( my $res = $cb->(POST '/author/_search',
                Content => $search,
            ), "POST _search" );

        is $res->code, 403, 'Not allowed';

        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' )
            or diag explain $res;

        is_deeply $json, { message => "$error_message" },
            "error returned for $desc";
    }
};


my %replacements = (
    prefer_shorter_module_names_100 =>
        qr#\Q_score - doc['documentation'].stringValue.length()/100\E#,

    prefer_shorter_module_names_400 =>
        qr#\Qif(documentation == empty)\E.+\Q.length()/400\E#s,

    score_version_numified =>
        qr#\Qdoc['module.version_numified'].value\E#,
);

while( my ($mscript, $re) = each %replacements ){
    my $query = filtered_custom_score_hash(metacpan_script => $mscript);

    my $sanitizer = MetaCPAN::Server::QuerySanitizer->new(
        query => $query,
    );

    my $cleaned = $sanitizer->query;
    like delete $cleaned->{query}{filtered}{query}{custom_score}{script},
        $re, "$mscript script replaced";

    is_deeply $cleaned, filtered_custom_score_hash(),
        'metacpan_script removed';

    # try another hash structure
    $query = { foo => { bar => [ { metacpan_script => $mscript, other => 'val' } ] } };

    $cleaned = MetaCPAN::Server::QuerySanitizer->new(query => $query)->query;

    like delete $cleaned->{foo}{bar}->[0]->{script},
        $re, "$mscript script replaced";
    is_deeply $cleaned, { foo => { bar => [ { other => 'val' } ] } },
        'any hash structure accepts metacpan_script';
}

hash_key_rejected(script => { script => 'foobar' });
hash_key_rejected(script => { tree => { of => 'many', hashes => { script => 'foobar' }}});
hash_key_rejected(script => { with => { arrays => [ {of => 'hashes'}, { script => 'foobar' } ] }});

{
    my $hash = filtered_custom_score_hash(hi => 'there');

    is_deeply
        delete $hash->{query}{filtered}{query},
        { custom_score => { query => { foo => 'bar' }, hi => 'there' } },
        'remove custom_score hash';

    $hash->{query}{filtered}{fooey} = {};

    is_deeply
        +MetaCPAN::Server::QuerySanitizer->new(query => $hash)->query,
        { query => { filtered => { fooey => {} } }, },
        'test that sanitizing does not autovivify hash keys';
}

done_testing;

sub filtered_custom_score_hash {
    return {
        query => { filtered => { query => { custom_score => {
            query => { foo => 'bar' },
            @_
        } } } }
    };
}

sub hash_key_rejected {
    my ($key, $hash) = @_;
    my $e;
    try {
        MetaCPAN::Server::QuerySanitizer->new(query => $hash)->query
    }
    catch {
        $e = $_[0];
    };

    if( defined $e ){
        like $e, qr/Parameter "$key" not allowed/, "died for bad key '$key'";
    }
    else {
        ok 0, 'error expected but not found';
    }
}
