# API Docs: v1

For an introduction to the MetaCPAN API (Application Program Interface) which requires no previous knowledge of MetaCPAN or ElasticSearch, see [the slides for "Abusing MetaCPAN for Fun and Profit"](https://www.slideshare.net/oalders/abusing-metacpan2013) or [watch the actual talk](https://www.youtube.com/watch?v=J8ymBuFlHQg). This API lets you programmatically access MetaCPAN from your own applications.

There is also [a repository of examples](https://github.com/metacpan/metacpan-examples) you can play with to get up and running in a hurry.  Rather than editing this wiki page, please send pull requests for the metacpan-examples repository.  If you'd rather edit the wiki, please do, but sending the code pull requests is probably the most helpful way to approach this.

_All of these URLs can be tested using the [MetaCPAN Explorer](https://explorer.metacpan.org)_

To learn more about the ElasticSearch query DSL (Domain-Specific Language) check out Clinton Gormley's [Terms of Endearment - ES Query DSL Explained](https://www.slideshare.net/clintongormley/terms-of-endearment-the-elasticsearch-query-dsl-explained) slides.

The query syntax is explained on ElasticSearch's [reference page](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/query-dsl.html). You can also check out this getting started tutorial about Elasticsearch [reference page](http://joelabrahamsson.com/elasticsearch-101/).

## Being polite

Currently, the only rules around using the API are to "be polite". We have enforced an upper limit of a size of 5,000 on search requests.  If you need to fetch more than 5,000 items, you should look at using the scrolling API.  Search this page for "scroll" to get an example using [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch) or see the [Elasticsearch scroll docs](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-scroll.html) if you are connecting in some other way.

You can certainly scroll if you are fetching less than 5,000 items.  You might want to do this if you are expecting a large data set, but will still need to run many requests to get all of the required data.

Be aware that when you scroll, your docs will come back unsorted, as noted in the [ElasticSearch scan documentation](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-search-type.html#scan).

## Identifying Yourself

Part of being polite is letting us know who you are and how to reach you.  This is not mandatory, but please do consider adding your app to the [API-Consumers](https://github.com/metacpan/metacpan-api/wiki/fastapi-Consumers) page.

## Available fields

Available fields can be found by accessing the corresponding `_mapping` endpoint.


* [`/author/_mapping`](https://fastapi.metacpan.org/v1/author/_mapping) - [explore](https://explorer.metacpan.org/?url=/author/_mapping)
* [`/distribution/_mapping`](https://fastapi.metacpan.org/v1/distribution/_mapping) - [explore](https://explorer.metacpan.org/?url=/distribution/_mapping)
* [`/favorite/_mapping`](https://fastapi.metacpan.org/v1/favorite/_mapping) - [explore](https://explorer.metacpan.org/?url=/favorite/_mapping)
* [`/file/_mapping`](https://fastapi.metacpan.org/v1/file/_mapping) - [explore](https://explorer.metacpan.org/?url=/file/_mapping)
* [`/module/_mapping`](https://fastapi.metacpan.org/v1/module/_mapping) - [explore](https://explorer.metacpan.org/?url=/module/_mapping)
* [`/release/_mapping`](https://fastapi.metacpan.org/v1/release/_mapping) - [explore](https://explorer.metacpan.org/?url=/release/_mapping)


## Field documentation

Fields are documented in the API codebase: https://github.com/metacpan/metacpan-api/tree/master/lib/MetaCPAN/Document  Check the Pod for discussion of what the various fields represent.  Be sure to have a look at https://github.com/metacpan/metacpan-api/blob/master/lib/MetaCPAN/Document/File.pm in particular as results for /module are really a thin wrapper around the `file` type.

## Search without constraints

Performing a search without any constraints is an easy way to get sample data

* [`/author/_search`](https://fastapi.metacpan.org/v1/author/_search)
* [`/distribution/_search`](https://fastapi.metacpan.org/v1/distribution/_search)
* [`/favorite/_search`](https://fastapi.metacpan.org/v1/favorite/_search)
* [`/file/_search`](https://fastapi.metacpan.org/v1/file/_search)
* [`/release/_search`](https://fastapi.metacpan.org/v1/release/_search)

## JSONP

Simply add a `callback` query parameter with the name of your callback, and you'll get a JSONP response.

* [/favorite?q=distribution:Moose&callback=cb](https://fastapi.metacpan.org/favorite?q=distribution:Moose&callback=cb)

## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

### `/distribution/{distribution}`

The `/distribution` endpoint accepts the name of a `distribution` (e.g. [/distribution/Moose](https://fastapi.metacpan.org/v1/distribution/Moose)), which returns information about the distribution which is not specific to a version (like RT bug counts).

### `/download_url/{module}`

The `/download_url` endpoint exists specifically for the `cpanm` client.  It takes a module name with an optional version (or range of versions) and an optional `dev` flag (for development releases) and returns a `download_url` as well as some other helpful info.

Obviously anyone can use this endpoint, but we'll only consider changes to this endpoint after considering how `cpanm` might be affected.

* [`https://fastapi.metacpan.org/v1/download_url/HTTP::Tiny`](https://fastapi.metacpan.org/v1/download_url/HTTP::Tiny)
* [`https://fastapi.metacpan.org/v1/download_url/Moose?version===0.01`](https://fastapi.metacpan.org/v1/download_url/Moose?version===0.01)
* [`https://fastapi.metacpan.org/v1/download_url/Moose?version=!=0.01`](https://fastapi.metacpan.org/v1/download_url/Moose?version=!=0.01)
* [`https://fastapi.metacpan.org/v1/download_url/Moose?version=<=0.02`](https://fastapi.metacpan.org/v1/download_url/Moose?version=<=0.02)
* [`https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27,!=0.24`](https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27,!=0.24)
* [`https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27&dev=1`](https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27&dev=1)
* [`https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27,!=0.26&dev=1`](https://fastapi.metacpan.org/v1/download_url/Try::Tiny?version=>0.21,<0.27,!=0.26&dev=1)

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [`/release/Moose`](https://fastapi.metacpan.org/v1/release/Moose)), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. [`/release/DOY/Moose-2.0001`](https://fastapi.metacpan.org/v1/release/DOY/Moose-2.0001)).

### `/author/{author}`

`author` refers to the pauseid of the author. It must be uppercased (e.g. [`/author/DOY`](https://fastapi.metacpan.org/v1/author/DOY)).

### `/module/{module}`

Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [`/module/Moose`](https://fastapi.metacpan.org/v1/module/Moose) is the same as [`/file/DOY/Moose-2.0001/lib/Moose.pm`](https://fastapi.metacpan.org/v1/file/DOY/Moose-2.0001/lib/Moose.pm).

### `/pod/{module}`

### `/pod/{author}/{release}/{path}`

Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [`/pod/Moose?content-type=text/plain`](https://fastapi.metacpan.org/v1/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:

* text/html (default)
* text/plain
* text/x-pod
* text/x-markdown

### `/source/{module}`

Returns the full source of the latest, authorized version of the given
`module`.

## GET Searches

Names of latest releases by OALDERS:

[`https://fastapi.metacpan.org/v1/release/_search?q=author:OALDERS%20AND%20status:latest&fields=name,status&size=100`](https://fastapi.metacpan.org/v1/release/_search?q=author:OALDERS%20AND%20status:latest&fields=name,status&size=100)

5,000 CPAN Authors:

[`https://fastapi.metacpan.org/v1/author/_search?q=*&size=5000`](https://fastapi.metacpan.org/author/_search?q=*)

All CPAN Authors Who Have Provided Twitter IDs:

https://fastapi.metacpan.org/v1/author/_search?q=profile.name:twitter

All CPAN Authors Who Have Updated MetaCPAN Profiles:

https://fastapi.metacpan.org/v1/author/_search?q=updated:*&sort=updated:desc

First 100 distributions which SZABGAB has given a ++:

https://fastapi.metacpan.org/v1/favorite/_search?q=user:sWuxlxYeQBKoCQe1f-FQ_Q&size=100&fields=distribution

The 100 most recent releases ( similar to https://metacpan.org/recent )

https://fastapi.metacpan.org/v1/release/_search?q=status:latest&fields=name,status,date&sort=date:desc&size=100

Number of ++'es that DOY's dists have received:

https://fastapi.metacpan.org/v1/favorite/_search?q=author:DOY&size=0

List of users who have ++'ed DOY's dists and the dists they have ++'ed:

https://fastapi.metacpan.org/v1/favorite/_search?q=author:DOY&fields=user,distribution

Last 50 dists to get a ++:

https://fastapi.metacpan.org/v1/favorite/_search?size=50&fields=author,user,release,date&sort=date:desc

The Changes file of the Test-Simple distribution:

https://fastapi.metacpan.org/v1/changes/Test-Simple

## Querying the API with MetaCPAN::Client

Perhaps the easiest way to get started using MetaCPAN is with [MetaCPAN::Client](https://metacpan.org/pod/MetaCPAN::Client).

You can get started with [this example script to fetch author data](https://github.com/metacpan/metacpan-examples/blob/master/scripts/author/1-fetch-single-author.pl).

## Querying the API with Search::Elasticsearch

The API server at fastapi.metacpan.org is a wrapper around an [Elasticsearch](https://elasticsearch.org) instance. It adds support for the convenient GET URLs, handles authentication and does some access control. Therefore you can use the powerful API of [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch) to query MetaCPAN.

**NOTE**: The `cxn_pool => 'Static::NoPing'` is important because of the HTTP proxy we have in front of Elasticsearch.

You can get started with [this example script to fetch author data](https://github.com/metacpan/metacpan-examples/blob/master/scripts/author/1-fetch-single-author-es.pl).

## POST Searches

Please feel free to add queries here as you use them in your own work, so that others can learn from you.

### Downstream Dependencies

This query returns a list of all releases which list MooseX::NonMoose as a
dependency.

```sh
curl -XPOST https://fastapi.metacpan.org/v1/release/_search -d '{
    "size" : 5000,
    "fields" : [ "distribution" ],
    "query" : {
        "bool" : {
            "must" : [
                { "term" : { "dependency.module" : "MooseX::NonMoose" } },
                { "term" : { "maturity" : "released" } },
                { "term" : { "status" : "latest" } }
            ]
        }
    }
}'
```

_Note it is also possible to use these queries in GET requests (useful for cross-domain JSONP requests) by appropriately encoding the JSON query into the `source` parameter of the URL.  For example the query above [would become](https://fastapi.metacpan.org/v1/release/_search?source=%7B%0A%20%20%20%20%22size%22%20%3A%205000%2C%0A%20%20%20%20%22fields%22%20%3A%20%5B%20%22distribution%22%20%5D%2C%0A%20%20%20%20%22query%22%20%3A%20%7B%0A%20%20%20%20%20%20%20%20%22bool%22%20%3A%20%7B%0A%20%20%20%20%20%20%20%20%20%20%20%20%22must%22%20%3A%20%5B%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22dependency.module%22%20%3A%20%22MooseX%3A%3ANonMoose%22%20%7D%20%7D%2C%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22maturity%22%20%3A%20%22released%22%20%7D%20%7D%2C%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22status%22%20%3A%20%22latest%22%20%7D%20%7D%0A%20%20%20%20%20%20%20%20%20%20%20%20%5D%0A%20%20%20%20%20%20%20%20%7D%0A%20%20%20%20%7D%0A%7D):_

```
curl 'https://fastapi.metacpan.org/v1/release/_search?source=%7B%0A%20%20%20%20%22size%22%20%3A%205000%2C%0A%20%20%20%20%22fields%22%20%3A%20%5B%20%22distribution%22%20%5D%2C%0A%20%20%20%20%22query%22%20%3A%20%7B%0A%20%20%20%20%20%20%20%20%22bool%22%20%3A%20%7B%0A%20%20%20%20%20%20%20%20%20%20%20%20%22must%22%20%3A%20%5B%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22dependency.module%22%20%3A%20%22MooseX%3A%3ANonMoose%22%20%7D%20%7D%2C%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22maturity%22%20%3A%20%22released%22%20%7D%20%7D%2C%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%7B%20%22term%22%20%3A%20%7B%20%22status%22%20%3A%20%22latest%22%20%7D%20%7D%0A%20%20%20%20%20%20%20%20%20%20%20%20%5D%0A%20%20%20%20%20%20%20%20%7D%0A%20%20%20%20%7D%0A%7D'
```

### [The size of the CPAN unpacked](https://github.com/metacpan/metacpan-examples/blob/master/scripts/file/5-size-of-cpan.pl)


### Get license types of all releases in an arbitrary time span:

```sh
curl -XPOST https://fastapi.metacpan.org/v1/release/_search?size=100 -d '{
    "query" : {
        "range" : {
            "date" : {
                "gte" : "2010-06-05T00:00:00",
                "lte" : "2011-06-05T00:00:00"
            }
        }
    },
    "fields": [ "license", "name", "distribution", "date", "version_numified" ]
}'
```

### Aggregate by license:

```sh
curl -XPOST https://fastapi.metacpan.org/v1/release/_search -d '{
    "query" : {
        "match_all" : {}
    },
    "aggs" : {
        "license" : {
            "terms" : {
                "field" : "license"
            }
        }
    },
    "size" : 0
}'
```

### Most used file names in the root directory of releases:

```sh
curl -XPOST https://fastapi.metacpan.org/v1/file/_search -d '{
    "query" : {
        "term" : { "level" : 0 }
    },
    "aggs" : {
        "license" : {
            "terms" : {
                "size" : 100,
                "field" : "name"
            }
        }
    },
    "size" : 0
}'
```

### Find all releases that contain a particular version of a module:

```sh
curl -XPOST https://fastapi.metacpan.org/v1/file/_search -d '{
    "query" : {
        "bool" : {
            "must" : [
                { "term" : { "module.name" : "DBI::Profile" } },
                { "term" : { "module.version" : "2.014123" } }
            ]
        }
    },
    "fields" : [ "release" ]
}'
```

### [Find all authors with Twitter in their profiles](https://github.com/metacpan/metacpan-examples/blob/master/scripts/author/1c-scroll-all-authors-with-twitter-es.pl)

### [Get a leaderboard of ++'ed distributions](https://github.com/metacpan/metacpan-examples/blob/master/scripts/favorite/3-leaderboard-es.pl)

### [Get a leaderboard of Authors with Most Uploads](https://github.com/metacpan/metacpan-examples/blob/master/scripts/release/2-author-upload-leaderboard-es.pl)


### [Search for a release by name](https://github.com/metacpan/metacpan-examples/blob/master/scripts/release/1-pkg2url-es.pl)


### Get the latest version numbers of your favorite modules

Note that "size" should be the number of distributions you are looking for.

```sh
lynx --dump --post_data https://fastapi.metacpan.org/v1/release/_search <<EOL
{
    "query" : {
        "bool" : {
            "must" : [
                {
                    "terms" : {
                        "distribution" : [
                            "Mojolicious",
                            "MetaCPAN-API",
                            "DBIx-Class"
                        ]
                    }
                },
                { "term" : { "status" : "latest" } }
            ]
        }
    },
    "fields" : [ "distribution", "version" ],
    "size" : 3
}
EOL
```

### Get a list of all files where the directory is false and the path is blank
```sh
curl -XPOST https://fastapi.metacpan.org/v1/file/_search -d '{
    "query" : {
        "bool" : {
            "must" : [
                { "term" : { "directory" : false } },
                { "term" : { "path" : "" } }
            ]
        }
    },
    "size" : 1000,
    "fields" : [ "name", "status", "directory", "path", "distribution" ],
}'
```

### List releases which have an email address for a bugtracker, but not an url
```sh
curl -XPOST https://fastapi.metacpan.org/v1/release/_search -d '{
    "query" : {
        "bool" : {
            "must" : [
                { "term" : {"maturity" : "released"} },
                { "term" : {"status" : "latest"} },
                {  "exists" : { "field" : "resources.bugtracker.mailto" } }
            ],
            "must_not" : [
                { "exists" : { "field" : "resources.bugtracker.web" } }
            ]
        }
    },
    "size": 10,
    "fields": [ "name", "resources.bugtracker.mailto" ],
}'
```

### [List distributions for which we have RT issues](https://github.com/metacpan/metacpan-examples/blob/master/scripts/release/2-dists-with-rt-source.pl)


### Search the current PDL documentation for the string `axisvals`
```sh
curl -XPOST https://fastapi.metacpan.org/v1/file/_search -d '{
    "query" : {
        "bool" : {
            "must" : [
                "query_string" : {
                    "query" : "axisvals",
                    "fields" : [ "pod.analyzed", "module.name" ]
                },
                { "term" : { "distribution" : "PDL" } },
                { "term" : { "status" : "latest" } }
            ]
        }
    },
    "fields" : [ "documentation", "abstract", "module.name" ],
    "size" : 20
}'
```
