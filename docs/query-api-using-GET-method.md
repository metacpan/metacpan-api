## GET convenience URLs

You should be able to run most POST queries, but very few GET urls are currently exposed. However, these convenience endpoints can get you started.  You should note that they behave differently than the POST queries in that they will return to you the latest version of a module or dist and they remove a lot of the verbose ElasticSearch data which wraps results.

### `/distribution/{distribution}`

The `/distribution` endpoint accepts the name of a `distribution` (e.g. [/distribution/Moose](http://api.metacpan.org/v0/distribution/Moose)), which returns information about the distribution which is not specific to a version (like RT bug counts).

### `/release/{distribution}`

### `/release/{author}/{release}`

The `/release` endpoint accepts either the name of a `distribution` (e.g. [/release/Moose](http://api.metacpan.org/v0/release/Moose)), which returns the most recent release of the distribution. Or provide the full path which consists of its `author` and the name of the `release` (e.g. (/release/DOY/Moose-2.0001](http://api.metacpan.org/v0/release/DOY/Moose-2.0001)).

### `/author/{author}`

`author` refers to the pauseid of the author. It must be uppercased (e.g. [/author/DOY](http://api.metacpan.org/v0/author/DOY)).

### `/module/{module}`

Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [/module/Moose](http://api.metacpan.org/v0/module/Moose) is the same as [/file/DOY/Moose-2.0001/lib/Moose.pm](http://api.metacpan.org/v0/file/DOY/Moose-2.0001/lib/Moose.pm).

### `/pod/{module}`

### `/pod/{author}/{release}/{path}`

Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [/pod/Moose?content-type=text/plain](http://api.metacpan.org/v0/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:

* text/html (default)
* text/plain
* text/x-pod
* text/x-markdown

## GET Searches

Names of latest releases by OALDERS:

[http://api.metacpan.org/v0/release/_search?q=author:OALDERS%20AND%20status:latest&fields=name,status&size=100]()

All CPAN Authors:

[http://api.metacpan.org/v0/author/_search?pretty=true&q=*&size=100000](http://api.metacpan.org/author/_search?pretty=true&q=*)

All CPAN Authors Who Have Provided Twitter IDs:

[http://api.metacpan.org/v0/author/_search?pretty=true&q=author.profile.name:twitter]()

All CPAN Authors Who Have Updated MetaCPAN Profiles:

[http://api.metacpan.org/v0/author/_search?q=updated:*&sort=updated:desc]()

First 100 distributions which SZABGAB has given a ++:

[http://api.metacpan.org/v0/favorite/_search?q=user:sWuxlxYeQBKoCQe1f-FQ_Q&size=100&fields=distribution]()

The 100 most recent releases ( similar to https://metacpan.org/recent )

[http://api.metacpan.org/v0/release/_search?q=status:latest&fields=name,status,date&sort=date:desc&size=100]()

Number of ++'es that DOY's dists have received:

[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&size=0]()

List of users who have ++'ed DOY's dists and the dists they have ++'ed:

[http://api.metacpan.org/v0/favorite/_search?q=author:DOY&fields=user,distribution]()

Last 50 dists to get a ++:

[http://api.metacpan.org/v0/favorite/_search?size=50&fields=author,user,release,date&sort=date:desc]()