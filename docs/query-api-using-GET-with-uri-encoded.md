## GET Searches

It is also possible to use these queries in GET requests (useful for cross-domain JSONP requests) by appropriately encoding the JSON query into the `source` parameter of the URL.  For example the query below:

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

[would become](http://api.metacpan.org/v0/release/_search?source=%7B%22query%22%3A%7B%22match_all%22%3A%7B%7D%7D%2C%22size%22%3A5000%2C%22fields%22%3A%5B%22distribution%22%5D%2C%22filter%22%3A%7B%22and%22%3A%5B%7B%22term%22%3A%7B%22release.dependency.module%22%3A%22MooseX%3A%3ANonMoose%22%7D%7D%2C%7B%22term%22%3A%7B%22release.maturity%22%3A%22released%22%7D%7D%2C%7B%22term%22%3A%7B%22release.status%22%3A%22latest%22%7D%7D%5D%7D%7D):

```sh
curl 'api.metacpan.org/v0/release/_search?source=%7B%22query%22%3A%7B%22match_all%22%3A%7B%7D%7D%2C%22size%22%3A5000%2C%22fields%22%3A%5B%22distribution%22%5D%2C%22filter%22%3A%7B%22and%22%3A%5B%7B%22term%22%3A%7B%22release.dependency.module%22%3A%22MooseX%3A%3ANonMoose%22%7D%7D%2C%7B%22term%22%3A%7B%22release.maturity%22%3A%22released%22%7D%7D%2C%7B%22term%22%3A%7B%22release.status%22%3A%22latest%22%7D%7D%5D%7D%7D'
```