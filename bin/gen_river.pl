#!/usr/bin/env perl 
use Mojo::Base -base;

use MetaCPAN::Client;
use Mojo::UserAgent;
use Term::ProgressBar;

sub import_release_data {
    my $self = shift;
    warn 'Importing releases';

    my $mcpan=MetaCPAN::Client->new();
    my $releases = $mcpan->all("releases",{es_filter=> {
        and => [
            { term => {authorized => 1 }, },
            { term => { status => 'latest'} },
        ],
        },
        scroller_time=>'1h'});

    my $i        = 0;
    my $ua=Mojo::UserAgent->new();
    my $cypher_url=Mojo::URL->new('http://neo4j:neo4j@localhost:7474/db/data/cypher');
    my $total    = $releases->total;
    my $progress = Term::ProgressBar->new($total);
    while ( my $release = $releases->next ) {
        next unless my $module=$release->{data}->{main_module};
        my $tx=$ua->post($cypher_url,json=> { query=> "MERGE (n:Module { name : \"$module\" }) RETURN n" });
        die Data::Dumper::Dumper $tx->res->json unless $tx->res->is_success && $tx->res->code =~ /^2/;
        my $node_id=$tx->res->json->{data}->[0]->[0]->{metadata}->{id};
        for my $dep ( @{ $release->{data}->{dependency} } ) {
            my $dep_module=$dep->{module};
            my $dep_tx=$ua->post($cypher_url,json=> { query=> "MERGE (n:Module { name : \"$dep_module\" }) RETURN n" });
            die Data::Dumper::Dumper $dep_tx->res->json unless $dep_tx->res->is_success && $dep_tx->res->code =~ /^2/;
            my $rel_tx=$ua->post($cypher_url,json=> {
                query => "MATCH (rel:Module { name: \"$module\"}), (dep:Module { name: \"$dep_module\" })".
                         "MERGE (rel)-[r:DEPENDS_ON]->(dep)  RETURN dep.name" });
            die Data::Dumper::Dumper $rel_tx->res->json unless $rel_tx->res->is_success && $rel_tx->res->code =~ /^2/;
        }
        $progress->update( ++$i );
   }
   $progress->update($total);
}

import_release_data();

1;
