# Beta API Docs

## Endpoints

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [[/release/Moose|http://api.beta.metacpan.org/release/Moose]]), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. [[/release/DOY/Moose-2.0001|http://api.beta.metacpan.org/release/DOY/Moose-2.0001]]).

### `/author/{author}`

`author` refers to the pauseid of the author. It must be uppercased (e.g. [[/author/DOY|http://api.beta.metacpan.org/author/DOY]]).

### `/module/{module}`

Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [[/module/Moose|http://api.beta.metacpan.org/module/Moose]] is the same as [[/file/DOY/Moose-2.0001/lib/Moose.pm|http://api.beta.metacpan.org/file/DOY/Moose-2.0001/lib/Moose.pm]].



## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

The latest Moose distribution currently on CPAN:

[http://api.beta.metacpan.org/release/Moose](http://api.beta.metacpan.org/release/Moose)

The latest version of Moose::Role (which is part of the Moose distribution):

[http://api.beta.metacpan.org/module/Moose::Role](http://api.beta.metacpan.org/module/Moose::Role)

Author info for FLORA:

[http://api.beta.metacpan.org/author/FLORA](http://api.beta.metacpan.org/author/FLORA)

## GET Searches

Names of latest releases by OALDERS:

[http://api.beta.metacpan.org/release/_search?q=author:OALDERS&filter=status:latest&fields=name&size=100](http://api.beta.metacpan.org/release/_search?q=author:OALDERS&filter=status:latest&fields=name&size=100)

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
