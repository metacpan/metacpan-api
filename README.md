[![Build Status](https://travis-ci.org/CPAN-API/cpan-api.png?branch=master)](https://travis-ci.org/CPAN-API/cpan-api)
[![Coverage Status](https://coveralls.io/repos/CPAN-API/cpan-api/badge.png)](https://coveralls.io/r/CPAN-API/cpan-api)

A Web Service for the CPAN
==========================

MetaCPAN aims to provide a free, open web service which provides metadata for
CPAN modules.

REST API
--------

MetaCPAN is based on ElasticSearch, so it provides a RESTful interface as well
as the option to create complex queries. [The
wiki](https://github.com/CPAN-API/cpan-api/wiki/API-docs) provides a good
starting point for REST access to MetaCPAN.

Expanding Your Author Info
--------------------------

MetaCPAN allows authors to add custom metadata about themselves to the index.
[Log in to MetaCPAN](https://metacpan.org/account/profile) to add more
information about yourself.

Installing Your Own MetaCPAN:
---------------------------------------

If you want to run MetaCPAN locally, we encourage you to start with a VM: [Metacpan Developer VM](https://github.com/CPAN-API/metacpan-developer)
However, you may still find some info here:

## Troubleshooting ElasticSearch

You can start ElasticSearch (ES) manually if you need to troubleshoot.
```sh
cd /opt/elasticsearch-0.20.2
sudo bin/elasticsearch
```
If you are unable to access [[http://localhost:9200]] (give it a few seconds) you should kill the elasticsearch process and run it in foreground to see the debug output
```sh
sudo service elasticsearch stop
sudo bin/elasticsearch -f
```
If you get a "Can't start up: not enough memory" error when trying to start ElasticSearch, you likely need to update your JRE.  On Ubuntu:
```sh
# fixes "not enough memory" errors
sudo apt-get install openjdk-6-jre
```
(Note: If you intend to try indexing a full mini-cpan, you may find that ElasticSearch wants to use more open filehandles than your system allows by default. [This script](https://gist.github.com/3230962) can be used to start ES with the appropriate ulimit adjustment).

## Run the test suite

The test suite accesses ElasticSearch on port 9900.
The developer vm should have a dedicated test instance running in the background already,
but if you want to run it manually:
```sh
bin/elasticsearch -f -Des.http.port=9900 -Des.cluster.name=testing
```
Then run the test suite:
```sh
cd /home/metacpan/api.metacpan.org
./bin/prove t
```
The test suite has to pass all tests.

## Create the ElasticSearch Index

```sh
./bin/metacpan mapping --delete
```

`--delete` will drop all indices first to clear the index from test data.

## Begin Indexing Your Modules

```sh
./bin/metacpan release /path/to/cpan/authors/id/
```
You should note that you can index either your CPAN mirror or a minicpan mirror.  You can even index just parts of a mirror:
```sh
./bin/metacpan release /path/to/cpan/authors/id/{A,B}
```

## Tag the Latest Releases

```sh
./bin/metacpan latest --cpan /path/to/cpan/
```

## Index Author Data

```sh
./bin/metacpan author --cpan /path/to/cpan/
```
Note that minicpan doesn't provide the 00whois.xml file which is used to generate the index; you will have to download it manually (it is in the authors/ directory) in order to index authors.

    wget -O /path/to/cpan/authors/00whois.xml cpan.cpantesters.org/authors/00whois.xml

It also doesn't include author.json files, so that data will also be missing unless you get it from somewhere else.

## Set Up Proxy in Front of ElasticSearch

Start API server on port 5000
```sh
./bin/carton exec plackup -p 5000 -r
```
This will start a single-threaded test server. If you need extra performance, use `starman` instead.

## Notes

For a full list of options:
```sh
./bin/metacpan release --help
```

EV may seem to take forever to install because the test suite hangs, so you may have to install it without first running the test suite:
```sh
cpanm --notest EV
```

Contributing:
-------------

If you'd like to get involved, find us at #metacpan or irc.perl.org or join
our mailing list (see below) and let us know what you'd like to start working
on.

IRC
---

You can find us at #metacpan on irc.perl.org

IRC logs can be found here:
[http://irclog.perlgeek.de/metacpan/today](http://irclog.perlgeek.de/metacpan/today)
(Thanks to [Moritz Lenz](http://moritz.faui2k3.org/) for making this service
available)

Mailing List
------------

Our mailing list is open to all:
[http://groups.google.com/group/cpan-api](http://groups.google.com/group/cpan-api) 
