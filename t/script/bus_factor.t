use strict;
use warnings;
use lib 't/lib';

use HTTP::Response              ();
use IO::Compress::Deflate       qw( deflate $DeflateError );
use IO::Compress::Gzip          qw( gzip $GzipError );
use MetaCPAN::Script::BusFactor ();
use MetaCPAN::Server::Config    ();
use Path::Tiny                  qw( tempdir );
use Test::Fatal                 qw( exception );
use Test::More;
use URI::file ();

my $dir  = tempdir();
my $json = '{"Foo-Bar":{"bus_factor":1,"pad":"' . ( 'x' x 5000 ) . '"}}';

sub script_for {
    my ( $file, %args ) = @_;
    my $script = MetaCPAN::Script::BusFactor->new(
        %{ MetaCPAN::Server::Config::config() },
        bus_factor_url => URI::file->new("$file")->as_string,
        max_feed_size  => 1000,
        %args,
    );

    # Normally done by run(); handle_error logs before it dies
    $script->set_logger_once;
    return $script;
}

subtest 'gzip that decompresses past the limit' => sub {
    my $file = $dir->child('bus_factor.json.gz');
    gzip \$json => "$file" or die $GzipError;
    cmp_ok -s $file, '<', 1000, 'compressed file is under the limit';

    like exception { script_for($file)->retrieve_bus_factor_data },
        qr/Decoded content would be larger than 1000 octets/, 'dies';
};

subtest 'raw body past the limit' => sub {
    my $file = $dir->child('bus_factor.json');
    $file->spew_raw($json);

    like exception { script_for($file)->retrieve_bus_factor_data },
        qr/Bus factor feed is larger than 1000 bytes/, 'dies';
};

subtest 'deflate, which decoded_content does not cap' => sub {
    deflate \$json => \my $deflated or die $DeflateError;
    my $script = script_for( $dir->child('never-fetched') );
    $script->ua->add_handler(
        request_send => sub {
            HTTP::Response->new(
                200, 'OK',
                [
                    'Content-Type'     => 'application/json',
                    'Content-Encoding' => 'deflate',
                ],
                $deflated
            );
        }
    );

    like exception { $script->retrieve_bus_factor_data },
        qr/unsupported Content-Encoding 'deflate'/, 'dies';
};

subtest 'HTTP error' => sub {

    # The testing config sets die_on_error, which would mask the fallthrough
    my $script
        = script_for( $dir->child('never-fetched'), die_on_error => 0 );
    $script->ua->add_handler( request_send =>
            sub { HTTP::Response->new( 500, 'Internal Server Error' ) } );

    like exception { $script->retrieve_bus_factor_data },
        qr/500 Internal Server Error/, 'dies';
};

done_testing();
