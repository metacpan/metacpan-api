## Querying the API with MetaCPAN::Client

Perhaps the easiest way to get started using MetaCPAN is with [MetaCPAN::Client](https://metacpan.org/pod/MetaCPAN::Client).  

```perl
use MetaCPAN::Client ();
my $mcpan  = MetaCPAN::Client->new();
my $author = $mcpan->author('XSAWYERX');
my $dist   = $mcpan->release('MetaCPAN-API');
```