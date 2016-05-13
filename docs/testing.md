# Testing

## Releases

When debugging the release indexing, try setting the bulk_size param to a low number, in order to make debugging easier.

    my $server = MetaCPAN::TestServer->new( ... );
    $server->index_releases( bulk_size => 1 );
    
You can enable Elasticsearch tracing when running tests at the command line:

    ES_TRACE=1 ./bin/prove t/darkpan.t
    
You'll then find extensive logging information in `es.log`, at the top level of your Git checkout.

## Indexing a Single Release

If you want to speed up your debugging, you can index a solitary release using
the `MC_RELEASE` environment variable.

    MC_RELEASE=var/t/tmp/fakecpan/authors/id/L/LO/LOCAL/P-1.0.20.tar.gz ./bin/prove t/00_setup.t

Or combine this with a test specific to the release.

    MC_RELEASE=var/t/tmp/fakecpan/authors/id/L/LO/LOCAL/P-1.0.20.tar.gz ./bin/prove t/00_setup.t t/release/p-1.0.20.t
