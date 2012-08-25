# Beta API Docs

_All of these URLs can be tested using tokuhirom's excellent [MetaCPAN Explorer](http://explorer.metacpan.org)_

To learn more about the ElasticSearch query DSL check out Clinton Gormley's [Terms of Endearment - ES Query DSL Explained] (http://www.slideshare.net/clintongormley/terms-of-endearment-the-elasticsearch-query-dsl-explained) slides.

## Being polite

Currently, the only rules around using the API are to "be polite". We have enforced an upper limit of a size of 5000 on search requests.  If you need to fetch more than 5000 items, you should look at using the scrolling API.  Search this page for "scroll" to get an example using ElasticSearch.pm or see the [ElasticSearch scroll docs](http://www.elasticsearch.org/guide/reference/api/search/scroll.html) if you are connecting in some other way.  

You can certainly scroll if you are fetching less than 5000 items.  You might want to do this if you are expecting a large data set, but will still need to run many requests to get all of the required data.

Be aware that when you scroll, your docs will come back unsorted, as noted in the [ElasticSearch scan documentation](http://www.elasticsearch.org/guide/reference/api/search/search-type.html).

## Identifying Yourself

Part of being polite is letting us know who you are and how to reach you.  This is not mandatory, but please do consider adding your app to the [[API-Consumers]] page.

## Available fields

Available fields can be found by accessing the corresponding `_mapping` endpoint.


* [[/author/_mapping|http://api.metacpan.org/v0/author/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/author/_mapping]]
* [[/distribution/_mapping|http://api.metacpan.org/v0/distribution/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/distribution/_mapping]]
* [[/favorite/_mapping|http://api.metacpan.org/v0/favorite/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/favorite/_mapping]]
* [[/file/_mapping|http://api.metacpan.org/v0/file/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/file/_mapping]]
* [[/rating/_mapping|http://api.metacpan.org/v0/rating/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/rating/_mapping]]
* [[/release/_mapping|http://api.metacpan.org/v0/release/_mapping]] - [[explore|http://explorer.metacpan.org/?url=/release/_mapping]]

## Field documentation

Fields are documented in the API codebase: [[https://github.com/CPAN-API/cpan-api/tree/master/lib/MetaCPAN/Document]]  Check the Pod for discussion of what the various fields represent.  Be sure to have a look at [[https://github.com/CPAN-API/cpan-api/blob/master/lib/MetaCPAN/Document/File.pm]] in particular as results for /module are really a thin wrapper around the file type.

## Search without constraints

Performing a search without any constraints is an easy way to get sample data

* [[/author/_search|http://api.metacpan.org/v0/author/_search]]
* [[/distribution/_search|http://api.metacpan.org/v0/distribution/_search]]
* [[/favorite/_search|http://api.metacpan.org/v0/favorite/_search]]
* [[/file/_search|http://api.metacpan.org/v0/file/_search]]
* [[/rating/_search|http://api.metacpan.org/v0/rating/_search]]
* [[/release/_search|http://api.metacpan.org/v0/release/_search]]

## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

## Joins

ElasticSearch itself doesn't support joining data across multiple types. The API server can, however, handle a `join` query parameter if the underlying type was set up accordingly. Browse [[https://github.com/CPAN-API/cpan-api/blob/master/lib/MetaCPAN/Server/Controller/]] to see all join conditions. Here are some examples.

Joins on documents:

* [[/author/PERLER?join=favorite|http://api.metacpan.org/v0/author/PERLER?join=favorite]]
* [[/author/PERLER?join=favorite&join=release|http://api.metacpan.org/v0/author/PERLER?join=favorite&join=release]]
* [[/release/Moose?join=author|http://api.metacpan.org/v0/release/Moose?join=author]]
* [[/module/Moose?join=release|http://api.metacpan.org/v0/module/Moose?join=release]]

Joins on search results is work in progress.

Restricting the joined results can be done by using the [[boolean "should"|http://www.elasticsearch.org/guide/reference/query-dsl/bool-query.html]] occurrence type:

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

* [[/favorite?q=distribution:Moose&callback=cb|http://api.metacpan.org/favorite?q=distribution:Moose&callback=cb]]

### `/distribution/{distribution}`

The `/distribution` endpoint accepts the name of a `distribution` (e.g. [[/distribution/Moose|http://api.metacpan.org/v0/distribution/Moose]]), which returns information about the distribution which is not specific to a version (like RT bug counts).

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [[/release/Moose|http://api.metacpan.org/v0/release/Moose]]), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. [[/release/DOY/Moose-2.0001|http://api.metacpan.org/v0/release/DOY/Moose-2.0001]]).

### `/author/{author}`

`author` refers to the pauseid of the author. It must be uppercased (e.g. [[/author/DOY|http://api.metacpan.org/v0/author/DOY]]).

### `/module/{module}`

Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [[/module/Moose|http://api.metacpan.org/v0/module/Moose]] is the same as [[/file/DOY/Moose-2.0001/lib/Moose.pm|http://api.metacpan.org/v0/file/DOY/Moose-2.0001/lib/Moose.pm]].

### `/pod/{module}`

### `/pod/{author}/{release}/{path}`

Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [[/pod/Moose?content-type=text/plain|http://api.metacpan.org/v0/pod/Moose?content-type=text/plain]] or by adding an `Accept` header to the HTTP request. Valid content types are:

* text/html (default)
* text/plain
* text/x-pod
* text/x-markdown

## GET Searches

Names of latest releases by OALDERS:

[[http://api.metacpan.org/v0/release/_search?q=author:OALDERS%20AND%20status:latest&fields=name,status&size=100]]

All CPAN Authors:

[http://api.metacpan.org/v0/author/_search?pretty=true&q=*&size=100000](http://api.metacpan.org/author/_search?pretty=true&q=*)

All CPAN Authors Who Have Provided Twitter IDs:

[[http://api.metacpan.org/v0/author/_search?pretty=true&q=author.profile.name:twitter]]

All CPAN Authors Who Have Updated MetaCPAN Profiles:

[[http://api.metacpan.org/v0/author/_search?q=updated:*&sort=updated:desc]]

First 100 distributions which SZABGAB has given a ++:

[[ http://api.metacpan.org/v0/favorite/_search?q=user:sWuxlxYeQBKoCQe1f-FQ_Q&size=100&fields=distribution]]

Number of ++'es that DOY's dists have received:

[[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&size=0]]

List of users who have ++'ed DOY's dists and the dists they have ++'ed:

[[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&fields=user,distribution]]

Last 50 dists to get a ++:

[[http://api.metacpan.org/v0/favorite/_search?size=50&fields=author,user,release,date&sort=date:desc]]

## Querying the API with MetaCPAN::API

Perhaps the easiest way to get started using MetaCPAN is with [MetaCPAN::API](https://metacpan.org/module/MetaCPAN::API).  

```perl
my $mcpan  = MetaCPAN::API->new();
my $author = $mcpan->author('XSAWYERX');
my $dist   = $mcpan->release( distribution => 'MetaCPAN-API' );
```

## Querying the API with ElasticSearch.pm

The API server at api.metacpan.org is a wrapper around an ElasticSearch instance. It adds support for the convenient GET URLs, handles authentication and does some access control. Therefore you can use the powerful API of [ElasticSearch.pm](https://metacpan.org/module/ElasticSearch) to query MetaCPAN:

```perl
use ElasticSearch;

my $es = ElasticSearch->new( servers => 'api.metacpan.org', no_refresh => 1 );

my $scroller = $es->scrolled_search(
    query       => { match_all => {} },
    search_type => 'scan',
    scroll      => '5m',
    index       => 'v0',
    type        => 'release',
    size        => 100,
);

while ( my $result = $scroller->next ) {
    print $result->{_source}->{author}, $/;
}
```

## POST Searches

Please feel free to add queries here as you use them in your own work, so that others can learn from you.

### Downstream Dependencies

This query returns a list of all releases which list MooseX::NonMoose as a
dependency.

```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{
  "query": {
    "match_all": {}
  },
  "size": 5000,
  "fields": [ "distribution" ],
  "filter": {
    "and": [
      { "term": { "release.dependency.module": "MooseX::NonMoose" } },
      { "term": {"release.maturity": "released"} },
      { "term": {"release.status": "latest"} }
    ]
  }
}'
```

_Note it is also possible to use these queries in GET requests (useful for cross-domain JSONP requests) by appropriately encoding the JSON query into the `source` parameter of the URL.  For example the query above [would become](http://api.metacpan.org/v0/release/_search?source=%7B%22query%22%3A%7B%22match_all%22%3A%7B%7D%7D%2C%22size%22%3A5000%2C%22fields%22%3A%5B%22distribution%22%5D%2C%22filter%22%3A%7B%22and%22%3A%5B%7B%22term%22%3A%7B%22release.dependency.module%22%3A%22MooseX%3A%3ANonMoose%22%7D%7D%2C%7B%22term%22%3A%7B%22release.maturity%22%3A%22released%22%7D%7D%2C%7B%22term%22%3A%7B%22release.status%22%3A%22latest%22%7D%7D%5D%7D%7D):_

```
curl 'api.metacpan.org/v0/release/_search?source=%7B%22query%22%3A%7B%22match_all%22%3A%7B%7D%7D%2C%22size%22%3A5000%2C%22fields%22%3A%5B%22distribution%22%5D%2C%22filter%22%3A%7B%22and%22%3A%5B%7B%22term%22%3A%7B%22release.dependency.module%22%3A%22MooseX%3A%3ANonMoose%22%7D%7D%2C%7B%22term%22%3A%7B%22release.maturity%22%3A%22released%22%7D%7D%2C%7B%22term%22%3A%7B%22release.status%22%3A%22latest%22%7D%7D%5D%7D%7D'
```

### The size of the CPAN unpacked

```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
  "query": { "match_all": {} },
  "facets": { 
    "size": {
      "statistical": {
        "field": "stat.size"
  } } },
  "size":0
}'
```

### Get license types of all releases in an arbitrary time span:

```sh
curl -XPOST api.metacpan.org/v0/release/_search?size=100 -d '{
  "query": {
    "match_all": {},
    "range" : {
        "release.date" : {
            "from" : "2010-06-05T00:00:00",
            "to" : "2011-06-05T00:00:00"
        }
    }
  },
  "fields": ["release.license", "release.name", "release.distribution", "release.date", "release.version_numified"]
}'
```

### Aggregate by license:

```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{
    "query": {
        "match_all": {}
    },
    "facets": {
        "license": {
            "terms": {
                "field": "release.license"
            }
        }
    },
    "size": 0
}'
```

### Most used file names in the root directory of releases:

```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
  "query": { "filtered":{"query":{"match_all":{}},"filter":{"term":{"level":0}}}
   },
  "facets": { 
    "license": {
      "terms": {
        "size":100,
        "field":"file.name"
  } } },
  "size":0
}'
```

### Find all releases that contain a particular version of a module:

```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
  "query": { "filtered":{
      "query":{"match_all":{}},
      "filter":{"and":[
          {"term":{"file.module.name":"DBI::Profile"}},
          {"term":{"file.module.version":"2.014123"}}
      ]}
  }},
  "fields":["release"]
}'
```
[example](http://explorer.metacpan.org/?url=%2Ffile&content=%7B%22query%22%3A%7B%22filtered%22%3A%7B%22query%22%3A%7B%22match_all%22%3A%7B%7D%7D%2C%22filter%22%3A%7B%22and%22%3A%5B%7B%22term%22%3A%7B%22file.module.name%22%3A%22DBI%3A%3AProfile%22%7D%7D%2C%7B%22term%22%3A%7B%22file.module.version%22%3A%222.014123%22%7D%7D%5D%7D%7D%7D%2C%22fields%22%3A%5B%22release%22%5D%7D)

### Find all authors with github-meets-cpan in their profiles
Because of the dashes in this profile name, we need to use a term.

```sh
curl -XPOST api.metacpan.org/v0/author/_search -d '{
  "query": {
    "match_all": {}
  },
  "filter": {
    "term": {
      "author.profile.name": "github-meets-cpan"
    }
  }
}'
```

### Get a leaderboard of ++'ed distributions

```sh
curl -XPOST api.metacpan.org/v0/favorite/_search -d '{
  "query": { "match_all": {}
   },
  "facets": { 
    "leaderboard": {
      "terms": {
        "field":"distribution",
        "size" : 100
  } } },
  "size":0
}'
```

### Get a leaderboard of Authors with Most Uploads

```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{
    "query": {
        "match_all": {}
    },
    "facets": {
        "author": {
            "terms": {
                "field": "author",
                "size": 100
            }
        }
    },
    "size": 0
}'
```

### Search for a release by name

```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{ 
  "query" : { "match_all" : {  } },
  "filter" : { "term" : { "release.name" : "YAML-Syck-1.07_01" } }
}'

```
### Get the latest version numbers of your favorite modules

Note that "size" should be the number of distributions you are looking for.

```sh
lynx --dump --post_data http://api.metacpan.org/v0/release/_search <<EOL 
{
    "query" : { "terms" : { "release.distribution" : [
        "Mojolicious",
        "MetaCPAN-API",
        "DBIx-Class"
    ] } },
    "filter" : { "term" : { "release.status" : "latest" } },
    "fields" : [ "distribution", "version" ],
    "size"   : 3
}
EOL
```

### Get a list of all files where the directory is false and the path is blank
```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
  "query": {
    "match_all": {}
  },
  "size": 1000,
  "fields": [ "name", "status", "directory", "path", "distribution" ],
  "filter": {
    "and": [
      { "term": { "directory": false } }, { "term" : { "path" : "" } }
    ]
  }
}'
```

### List releases which have an email address for a bugtracker, but not an url
```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{
  "query": {
    "match_all": {}
  },
  "size": 5,
  "fields": [ "release.name", "release.resources.bugtracker.mailto" ],
  "filter": {
    "and": [
      { "term": {"release.maturity": "released"} },
      { "term": {"release.status": "latest"} },
      {  "exists" : { "field" : "release.resources.bugtracker.mailto" } },
      {  "missing" : { "field" : "release.resources.bugtracker.web" } }
    ]
  }
}'
```