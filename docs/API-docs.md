The API itself is in its very early stages.  Everything will change, but here are some sample URLs to play with.  Keep in mind that these URLs all return JSON.

## Search for a Module by Distribution Name:
[[http://api.metacpan.org:9200/cpan-modules/module/_search?q=dist:moose]]

## Search for a Module by id:
[[http://api.metacpan.org:9200/cpan-modules/module/1]]

## Search for an Author

### By PAUSEID (exact match)
[[http://api.metacpan.org/author/DROLSKY]]

### By PAUSEID (wildcard match)
[[http://api.metacpan.org/author/_search?q=author:D*]]

### By Name (find all Daves)
[[http://api.metacpan.org/author/_search?q=name:Dave]]

### By Full Name
[[http://api.metacpan.org/author/_search?q=name:"dave%20rolsky"]]

