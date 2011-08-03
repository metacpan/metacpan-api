# Beta API Docs

_All of these URLs can be tested using tokuhirom's excellent [MetaCPAN Explorer](http://explorer.metacpan.org)_

## Available fields

Available fields can be found by accessing the corresponding `_mapping` endpoint.

* [[/release/_mapping|http://api.metacpan.org/v0/release/_mapping]]
* [[/author/_mapping|http://api.metacpan.org/v0/author/_mapping]]
* [[/module/_mapping|http://api.metacpan.org/v0/module/_mapping]]
* [[/file/_mapping|http://api.metacpan.org/v0/file/_mapping]]
* [[/favorite/_mapping|http://api.metacpan.org/v0/favorite/_mapping]]

## Search without constraints

Performing a search without any constraints is an easy way to get sample data

* [[/release/_search|http://api.metacpan.org/v0/release/_search]]
* [[/author/_search|http://api.metacpan.org/v0/author/_search]]
* [[/module/_search|http://api.metacpan.org/v0/module/_search]]
* [[/file/_search|http://api.metacpan.org/v0/file/_search]]
* [[/favorite/_search|http://api.metacpan.org/v0/favorite/_search]]

## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [[/release/Moose|http://api.metacpan.org/v0/release/Moose]]), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. [[/release/DOY/Moose-2.0001|http://api.metacpan.org/0/release/DOY/Moose-2.0001]]).

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

[http://api.metacpan.org/v0/author/_search?pretty=true&q=*&size=100000](http://api.metacpan.org/author/_search?pretty=true&q=*&size=100000)

All CPAN Authors Who Have Provided Twitter IDs:

[http://api.metacpan.org/v0/author/_search?pretty=true&q=profile.name:twitter&size=100000](http://api.metacpan.org/v0/author/_search?pretty=true&q=profile.name:twitter&size=100000)

All CPAN Authors Who Have Updated MetaCPAN Profiles:

[[http://api.metacpan.org/v0/author/_search?q=updated:*&sort=updated:desc]]

First 100 distributions which SZABGAB has given a +1:

[[http://api.metacpan.org/v0/favorite/_search?q=user:SZABGAB&size=100&fields=distribution]]

Number of favorites that DOY's dists have received:

[[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&size=0]]

List of users who have favorited DOY's dists and the dists they have voted on:

[[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&size=99999&fields=user,distribution]]

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
  "size": 999999,
  "filter": {
    "term": {
      "release.dependency.module": "MooseX::NonMoose"
    }
  }
}'
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

Aggregate by license:

```sh
curl -XPOST api.metacpan.org/v0/release/_search -d '{
  "query": { "range" : {
        "release.date" : {
            "from" : "2010-06-05T00:00:00",
            "to" : "2011-06-05T00:00:00",
        }
    }
   },
  "facets": { 
    "license": {

      "terms": {
        "field":"release.license"
  } } },
  "size":0
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