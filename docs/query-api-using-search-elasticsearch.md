## Querying the API with Search::Elasticsearch

The API server at api.metacpan.org is a wrapper around an [Elasticsearch](http://elasticsearch.org) instance. It adds support for the convenient GET URLs, handles authentication and does some access control. Therefore you can use the powerful API of [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch) to query MetaCPAN.

**NOTE**: The `cxn_pool => 'Static::NoPing'` is important because of the HTTP proxy we have in front of Elasticsearch.

```perl
use Search::Elasticsearch;

my $es =  Search::Elasticsearch->new(
    cxn_pool   => 'Static::NoPing',
    nodes      => 'api.metacpan.org'
);

my $scroller = $es->scroll_helper(
    search_type => 'scan',
    scroll      => '5m',
    index       => 'v0',
    type        => 'release',
    size        => 100,
    body => {
        query => {
            match_all =>  {} 
        }
    }
);

while ( my $result = $scroller->next ) {
    print $result->{_source}->{author}, '/',
          $result->{_source}->{name}, $/;
}
```