# Testing

## Releases

When debugging the release indexing, try setting the bulk_size param to a low number, in order to make debugging easier.

    my $server = MetaCPAN::TestServer->new( ... );
    $server->index_releases( bulk_size => 1 );
    
You can enable Elasticsearch tracing when running tests at the command line:

    ES_TRACE=1 ES=localhost:9200 ./bin/prove t/darkpan.t
    
You'll then find extensive logging information in `es.log`, at the top level of your Git checkout.
