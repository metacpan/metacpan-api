
# Search result comparison system

## Why

We want to improve MetaCPAN's search results, getting them at least as good as search.cpan.org's but ideally
even better.

## How

Run multiple searches (via the API that the web UI now uses), with different weights (that are now arguments) and compare to each other (so one weighthing doesn't
then break another, or at least we can come to some
balance).

### Installing

You will need postgres installed with a database
that matches the current user and the current user needs
access (the MetaCPAN developer vm sets this up for you).

```sh
cpanm Carton
carton install
```

### Running tests

```sh

carton exec /opt/perl-5.22.2/bin/perl ./app.pl eval 'app->perform_all_searches'
```

### Viewing results site
```sh
carton exec /opt/perl-5.22.2/bin/perl ./app.pl daemon -m production -l http://*:5000
```





