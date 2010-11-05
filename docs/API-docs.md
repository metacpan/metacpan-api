The API itself is in its very early stages.  Everything will change, but here are some sample URLs to play with.  Keep in mind that these URLs all return JSON.

## Search for a Module

### By Distribution Name:
[[http://api.metacpan.org/module/_search?q=dist:moose]]

### By Module Name:
[[http://api.metacpan.org/module/Moose::Meta::Attribute::Native::MethodProvider::Counter]]

## Search for an Author

### By PAUSEID (exact match)
[[http://api.metacpan.org/author/DROLSKY]]

### By PAUSEID (wildcard match)
[[http://api.metacpan.org/author/_search?q=author:D*]]

### By Name (find all Daves)
[[http://api.metacpan.org/author/_search?q=name:Dave]]

### By Full Name
[[http://api.metacpan.org/author/_search?q=name:%22dave%20rolsky%22]]

## Search for CPANRatings ([[http://cpanratings.perl.org/]])

### By Distribution Name (exact Match)
[[http://api.metacpan.org/cpanratings/Moose]]

### By Distribution Name (find all rated Moose distros)
[[http://api.metacpan.org/cpanratings/_search?q=dist:Moose]]
