package MetaCPAN;

use Modern::Perl;
use Moose;
use ElasticSearch;

has 'es' => ( is => 'rw', lazy_build => 1 );

sub _build_es {

    my $e = ElasticSearch->new(
        servers     => 'localhost:9200',
        transport   => 'http', # default 'http'
        trace_calls => 'log_file',
    );

}


1;
