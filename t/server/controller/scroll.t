use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    test_scroll_methods($cb);
    test_missing_scroll_id($cb);
};

sub test_missing_scroll_id {
    my $cb = shift;
    foreach my $req (
        [ scroll_url_param(),    'url param' ],
        [ scroll_post_body(),    'post body' ],
        [ scroll_query_string(), 'query string' ],
        )
    {
        is_deeply(
            req_json( $cb, @$req, 500 ),
            { message => 'Scroll Id required' },
            "error without scroll_id in $req->[-1]",
        );
    }
}

sub scroll_start {
    return GET '/release/_search?size=1&scroll=5m';
}

sub scroll_url_param {
    my $scroll_id = shift || q[];
    return GET "/_search/scroll/$scroll_id?scroll=5m";
}

sub scroll_post_body {
    my $scroll_id = shift || q[];

    # Use text/plain to avoid Catalyst trying to process the body.
    return POST '/_search/scroll?scroll=5m',
        Content_type => 'text/plain',
        Content      => $scroll_id;
}

sub scroll_query_string {
    my $scroll_id = shift || q[];
    return GET "/_search/scroll/?scroll_id=$scroll_id&scroll=5m";
}

sub req_json {
    my ( $cb, $req, $desc, $code ) = @_;
    ok( my $res = $cb->($req), $desc );

    $code ||= 200;
    is( $res->code, $code, "HTTP $code" )
        or diag Test::More::explain($res);

    my $json = decode_json_ok($res);
    return $json;
}

sub test_scroll_methods {
    my $cb = shift;

    my $steps = [
        sub {
            req_json( $cb, scroll_start(), 'start scroll' );
        },
        sub {
            req_json(
                $cb,
                scroll_url_param( $_[0] ),
                'continue scroll with scroll_id in GET url'
            );
        },
        sub {
            req_json(
                $cb,
                scroll_post_body( $_[0] ),
                'continue scroll with scroll_id in POST body'
            );
        },
        sub {
            req_json(
                $cb,
                scroll_query_string( $_[0] ),
                'continue scroll with scroll_id in query string'
            );
        },
    ];

    my $scroll_id;
    my @docs;

    # Repeat each type just to be sure.
    foreach my $step ( shift(@$steps), (@$steps) x 2 ) {

        # Pass in previous scroll_id.
        my $json = $step->($scroll_id);

        # Cache scroll_id for next call.
        $scroll_id = $json->{_scroll_id};

        # Save docs.
        push @docs, $json->{hits}{hits}[0];
        note $docs[-1]->{_source}{name};
    }

    my %ids = map { ( $_->{_id} => $_ ) } @docs;

    is scalar( keys(%ids) ), scalar(@docs), 'got a new doc each time';
}

done_testing;
