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
   "fields": [
      "distribution"
   ],
   "filter": {
      "and": [
         {
            "term": {
               "release.dependency.module": "MooseX::NonMoose"
            }
         },
         {
            "term": {
               "release.maturity": "released"
            }
         },
         {
            "term": {
               "release.status": "latest"
            }
         }
      ]
   }
}'
```

### The size of the CPAN unpacked

```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
   "query": {
      "match_all": {}
   },
   "facets": {
      "size": {
         "statistical": {
            "field": "stat.size"
         }
      }
   },
   "size": 0
}'
```

### Get license types of all releases in an arbitrary time span:

```sh
curl -XPOST api.metacpan.org/v0/release/_search?size=100 -d '{
   "query": {
      "match_all": {},
      "range": {
         "release.date": {
            "from": "2010-06-05T00:00:00",
            "to": "2011-06-05T00:00:00"
         }
      }
   },
   "fields": [
      "release.license",
      "release.name",
      "release.distribution",
      "release.date",
      "release.version_numified"
   ]
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
   "query": {
      "filtered": {
         "query": {
            "match_all": {}
         },
         "filter": {
            "term": {
               "level": 0
            }
         }
      }
   },
   "facets": {
      "license": {
         "terms": {
            "size": 100,
            "field": "file.name"
         }
      }
   },
   "size": 0
}'
```

### Find all releases that contain a particular version of a module:

```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
   "query": {
      "filtered": {
         "query": {
            "match_all": {}
         },
         "filter": {
            "and": [
               {
                  "term": {
                     "file.module.name": "DBI::Profile"
                  }
               },
               {
                  "term": {
                     "file.module.version": "2.014123"
                  }
               }
            ]
         }
      }
   },
   "fields": [
      "release"
   ]
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
  "query": {
    "match_all": {}
  },
  "facets": {
    "leaderboard": {
      "terms": {
        "field": "distribution",
        "size": 100
      }
    }
  },
  "size": 0
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
  "query": {
    "match_all": {}
  },
  "filter": {
    "term": {
      "release.name": "YAML-Syck-1.07_01"
    }
  }
}'

```
### Get the latest version numbers of your favorite modules

Note that "size" should be the number of distributions you are looking for.

```sh
lynx --dump --post_data http://api.metacpan.org/v0/release/_search <<EOL 
{
  "query": {
    "terms": {
      "release.distribution": [
        "Mojolicious",
        "MetaCPAN-API",
        "DBIx-Class"
      ]
    }
  },
  "filter": {
    "term": {
      "release.status": "latest"
    }
  },
  "fields": [
    "distribution",
    "version"
  ],
  "size": 3
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
  "fields": [
    "name",
    "status",
    "directory",
    "path",
    "distribution"
  ],
  "filter": {
    "and": [
      {
        "term": {
          "directory": false
        }
      },
      {
        "term": {
          "path": ""
        }
      }          
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
  "size": 10,
  "fields": [
    "release.name",
    "release.resources.bugtracker.mailto"
  ],
  "filter": {
    "and": [
      {
        "term": {
          "release.maturity": "released"
        }
      },
      {
        "term": {
          "release.status": "latest"
        }
      },
      {
        "exists": {
          "field": "release.resources.bugtracker.mailto"
        }
      },
      {
        "missing": {
          "field": "release.resources.bugtracker.web"
        }
      }
    ]
  }
}'
```

### List distributions for which we have a bugtracker URL

```sh
curl -XPOST api.metacpan.org/v0/distribution/_search -d '{
   "query": {
      "match_all": {}
   },
   "size": 1000,
   "filter": {
      "exists": {
         "field": "distribution.bugs.source"
      }
   }
}'
```

### Search the current PDL documentation for the string `axisvals`
```sh
curl -XPOST api.metacpan.org/v0/file/_search -d '{
  "query": {
    "filtered": {
      "query": {
        "query_string": {
          "query": "axisvals",
          "fields": [
            "pod.analyzed",
            "module.name"
          ]
        }
      },
      "filter": {
        "and": [
          {
            "term": {
              "distribution": "PDL"
            }
          },
          {
            "term": {
              "status": "latest"
            }
          }
        ]
      }
    }
  },
  "fields": [
    "documentation",
    "abstract",
    "module"
  ],
  "size": 20
}'
``` 