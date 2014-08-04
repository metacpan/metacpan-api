# API Docs: v0

For an introduction to the MetaCPAN API which requires no previous knowledge of MetaCPAN or ElasticSearch, see [the slides for "Abusing MetaCPAN for Fun and Profit"](http://www.slideshare.net/oalders/abusing-metacpan2013) or [watch the actual talk](http://www.youtube.com/watch?v=J8ymBuFlHQg).

There is also [a repository of examples](https://github.com/CPAN-API/metacpan-examples) you can play with to get up and running in a hurry.  Rather than editing this wiki page, please send pull requests for the metacpan-examples repository.  If you'd rather edit the wiki, please do, but sending the code pull requests is probably the most helpful way to approach this.

_All of these URLs can be tested using the [MetaCPAN Explorer](http://explorer.metacpan.org)_

To learn more about the ElasticSearch query DSL check out Clinton Gormley's [Terms of Endearment - ES Query DSL Explained](http://www.slideshare.net/clintongormley/terms-of-endearment-the-elasticsearch-query-dsl-explained) slides.

The query syntax is explained on ElasticSearch's [reference page](http://www.elasticsearch.org/guide/reference/query-dsl/).

## Being polite

Currently, the only rules around using the API are to "be polite". We have enforced an upper limit of a size of 5000 on search requests.  If you need to fetch more than 5000 items, you should look at using the scrolling API.  Search this page for "scroll" to get an example using [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch) or see the [Elasticsearch scroll docs](http://www.elasticsearch.org/guide/reference/api/search/scroll.html) if you are connecting in some other way.

You can certainly scroll if you are fetching less than 5000 items.  You might want to do this if you are expecting a large data set, but will still need to run many requests to get all of the required data.

Be aware that when you scroll, your docs will come back unsorted, as noted in the [ElasticSearch scan documentation](http://www.elasticsearch.org/guide/reference/api/search/search-type.html).

## Identifying Yourself

Part of being polite is letting us know who you are and how to reach you.  This is not mandatory, but please do consider adding your app to the [API-Consumers](https://github.com/CPAN-API/cpan-api/wiki/API-Consumers) page.

## Available fields

Available fields can be found by accessing the corresponding `_mapping` endpoint.


* [/author/_mapping](http://api.metacpan.org/v0/author/_mapping) - [explore](http://explorer.metacpan.org/?url=/author/_mapping)
* [/distribution/_mapping](http://api.metacpan.org/v0/distribution/_mapping) - [explore](http://explorer.metacpan.org/?url=/distribution/_mapping)
* [/favorite/_mapping](http://api.metacpan.org/v0/favorite/_mapping) - [explore](http://explorer.metacpan.org/?url=/favorite/_mapping)
* [/file/_mapping](http://api.metacpan.org/v0/file/_mapping) - [explore](http://explorer.metacpan.org/?url=/file/_mapping)
* [/module/_mapping](http://api.metacpan.org/v0/module/_mapping) - [explore](http://explorer.metacpan.org/?url=/module/_mapping)
* [/rating/_mapping](http://api.metacpan.org/v0/rating/_mapping) - [explore](http://explorer.metacpan.org/?url=/rating/_mapping)
* [/release/_mapping](http://api.metacpan.org/v0/release/_mapping) - [explore](http://explorer.metacpan.org/?url=/release/_mapping)


## Field documentation

Fields are documented in the API codebase: [https://github.com/CPAN-API/cpan-api/tree/master/lib/MetaCPAN/Document]()  Check the Pod for discussion of what the various fields represent.  Be sure to have a look at [https://github.com/CPAN-API/cpan-api/blob/master/lib/MetaCPAN/Document/File.pm]() in particular as results for /module are really a thin wrapper around the `file` type.

## Search without constraints

Performing a search without any constraints is an easy way to get sample data

* [/author/_search](http://api.metacpan.org/v0/author/_search)
* [/distribution/_search](http://api.metacpan.org/v0/distribution/_search)
* [/favorite/_search](http://api.metacpan.org/v0/favorite/_search)
* [/file/_search](http://api.metacpan.org/v0/file/_search)
* [/rating/_search](http://api.metacpan.org/v0/rating/_search)
* [/release/_search](http://api.metacpan.org/v0/release/_search)

## Joins

ElasticSearch itself doesn't support joining data across multiple types. The API server can, however, handle a `join` query parameter if the underlying type was set up accordingly. Browse [https://github.com/CPAN-API/cpan-api/blob/master/lib/MetaCPAN/Server/Controller/]() to see all join conditions. Here are some examples.

Joins on documents:

* [/author/PERLER?join=favorite](http://api.metacpan.org/v0/author/PERLER?join=favorite)
* [/author/PERLER?join=favorite&join=release](http://api.metacpan.org/v0/author/PERLER?join=favorite&join=release)
* [/release/Moose?join=author](http://api.metacpan.org/v0/release/Moose?join=author)
* [/module/Moose?join=release](http://api.metacpan.org/v0/module/Moose?join=release)

Joins on search results is work in progress.

Restricting the joined results can be done by using the [boolean "should"](http://www.elasticsearch.org/guide/reference/query-dsl/bool-query.html) occurrence type:

```sh
curl -XPOST http://api.metacpan.org/v0/author/PERLER?join=release -d '
{
    "query": {
        "bool": {
            "should": [{
                "term": {
                    "release.status": "latest"
                }
            }]
        }
    }
}'
```

## JSONP

Simply add a `callback` query parameter with the name of your callback, and you'll get a JSONP response.

* [/favorite?q=distribution:Moose&callback=cb](http://api.metacpan.org/favorite?q=distribution:Moose&callback=cb)

## How to use CPAN API

Here are methods which can be used to query the API:

* [GET](/docs/query-api-using-GET-method.md)
* [POST](/docs/query-api-using-POST-method.md)
* [GET with URI-encoded](/docs/query-api-using-GET-with-uri-encoded.md)
* [MetaCPAN::Client](/docs/query-api-using-metacpan-client.md)
* [Search::Elasticsearch](/docs/query-api-using-search-elasticsearch.md)
