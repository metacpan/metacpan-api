use strict;
use warnings;
use Test::Most;
use Plack::Test;
use MetaCPAN::Plack::File;
use Plack::Builder;
use HTTP::Request::Common;
use JSON::XS;
use MetaCPAN::Util;

my $app = builder {
    mount "/file" => MetaCPAN::Plack::File->new,
};

test_psgi $app, sub {
    my $cb  = shift;
    my $res = $cb->( GET "/file/KWILLIAMS/Path-Class-0.23/lib/Path/Class.pm" );
    my $json;
    lives_ok { $json = decode_json( $res->content ) } "valid JSON response";
    is ($json->{id}, MetaCPAN::Util::digest(qw(KWILLIAMS Path-Class-0.23 lib/Path/Class.pm)));
};

done_testing;