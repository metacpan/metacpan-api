The API itself is in its very early stages.  Everything will change, but here are some sample URLs to play with.

* All URLs return JSON
* For pretty JSON, pass the pretty parameter.  eg pretty=true
* To limit your results, pass the size parameter. eg size=100000
* To limit the fields returned, pass a comma-separated list in the fields param. eg fields=_source.distvname,_source.name
* To return no fields, just pass the fields param without values. eg fields=&

## Full text searching

###### First 10 modules with the word "RJBS" in the plain text Pod
[[http://api.metacpan.org/pod/_search?&fields=&q=text:rjbs&size=10]]

Note that this query returns no Pod fields because of the empty "fields" param.

###### First 10 modules with match on word fragment "RJB" in the plain text Pod
[[http://api.metacpan.org/pod/_search?&fields=&q=text:*rjb*&size=10]]

Note that this query returns no Pod fields because of the empty "fields" param.

###### Text Pod for First 10 modules with the word "RJBS" in the Pod
[[http://api.metacpan.org/pod/_search?&fields=_source.text&q=rjbs&size=10]]

###### HTML Pod for First 10 modules with the word "RJBS" in the Pod
[[http://api.metacpan.org/pod/_search?&fields=_source.html&q=rjbs&size=10]]

## Search for a Module

###### By name:
[[http://api.metacpan.org/module/Dancer::Cookbook]]

###### By distribution name:
[[http://api.metacpan.org/module/_search?q=distname:moose]]

###### By author name:

Note that for this type of search, the author id must be in lower case. 

[[http://api.metacpan.org/module/_search?q=author:oalders]]

Alternate syntax:

<pre><code>
curl -XPOST 'api.metacpan.org/module/_search?pretty=true' -d '{
    "query" : {
        "term" : { "author" : "oalders" }
    }
}
'
</code></pre>

Using the "field" key, the search term becomes case-insensitive:

<pre><code>curl -XPOST 'api.metacpan.org/module/_search?pretty=true' -d '{
    "query" : {
        "field" : { "author" : "Oalders"  }
    }
}
'</code></pre>

###### List all modules:
[[http://api.metacpan.org/module/_search?q=*&size=100000]]

Same list, but return only "name" and "distvname" fields:
[[http://api.metacpan.org/module/_search?&fields=_source.distvname,_source.name&q=*&size=100000]]

## Search for an author

###### By PAUSEID (exact match)
[[http://api.metacpan.org/author/DROLSKY]]

###### By PAUSEID (wildcard match)
[[http://api.metacpan.org/author/_search?q=author:D*]]

###### By name (find all Daves)
[[http://api.metacpan.org/author/_search?q=name:Dave]]

###### By full name
[[http://api.metacpan.org/author/_search?q=name:%22dave%20rolsky%22]]

###### List all authors
[[http://api.metacpan.org/author/_search?pretty=true&q=*&size=100000]]

## Search for Pod

###### By module name (exact Match)
[[http://api.metacpan.org/pod/HTML::Restrict]]

## Search for CPANRatings ([[http://cpanratings.perl.org/]])

###### By distribution name (exact match)
[[http://api.metacpan.org/cpanratings/Moose]]

###### By distribution name (find all rated Moose distros)
[[http://api.metacpan.org/cpanratings/_search?q=dist:Moose]]

