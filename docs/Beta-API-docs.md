# Beta API Docs

## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [[/release/Moose|http://api.beta.metacpan.org/release/Moose]]), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. [[/release/DOY/Moose-2.0001|http://api.beta.metacpan.org/release/DOY/Moose-2.0001]]).

### `/author/{author}`

`author` refers to the pauseid of the author. It must be uppercased (e.g. [[/author/DOY|http://api.beta.metacpan.org/author/DOY]]).

### `/module/{module}`

Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [[/module/Moose|http://api.beta.metacpan.org/module/Moose]] is the same as [[/file/DOY/Moose-2.0001/lib/Moose.pm|http://api.beta.metacpan.org/file/DOY/Moose-2.0001/lib/Moose.pm]].

### `/pod/{module}`

### `/pod/{author}/{release}/{path}`

Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [[/pod/Moose?content-type=text/plain|http://api.beta.metacpan.org/pod/Moose?content-type=text/plain]] or by adding an `Accept` header to the HTTP request. Valid content types are:

* text/html (default)
* text/plain
* text/x-pod
* text/x-markdown

## GET Searches

Names of latest releases by OALDERS:

[http://api.beta.metacpan.org/release/_search?q=author:OALDERS&filter=status:latest&fields=name&size=100](http://api.beta.metacpan.org/release/_search?q=author:OALDERS&filter=status:latest&fields=name&size=100)

Latest modules in the DBIx namespace:

[http://api.beta.metacpan.org/module/_search?q=status:latest%20AND%20name:DBIx](http://api.beta.metacpan.org/module/_search?q=status:latest%20AND%20name:DBIx)

## POST Searches

Please feel free to add queries here as you use them in your own work, so that others can learn from you.

### Downstream Dependencies

This query returns a list of all releases which list MooseX::NonMoose as a
dependency.

```sh
curl -XPOST api.beta.metacpan.org/release/_search -d '{
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

````sh
curl -XPOST api.beta.metacpan.org/file/_search -d '{
  "query": { "match_all": {} },
  "facets": { 
    "size": {
      "statistical": {
        "field": "stat.size"
  } } },
  "size":0
}'
````