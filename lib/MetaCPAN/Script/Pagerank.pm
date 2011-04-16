package MetaCPAN::Script::Pagerank;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Graph::Centrality::Pagerank;

sub run {
    my $self = shift;
    my $es = $self->es;
    my $pr = Graph::Centrality::Pagerank->new();
    my @edges;
    my $result = $es->search(
                        index => 'cpan',
                        type => 'dependency',
                        query=>{match_all=>{}},
                        filter=> { term => { phase => 'runtime' } },
                        scroll => '5m',
                        size => 1000,
                     );
    
        while (1) {
            my $hits = $result->{hits}{hits};
            last unless @$hits;                 # if no hits, we're finished
            for(@$hits) {
                my $release = $_->{_source}->{release};
                $release =~ s/^(.*)-.*?$/$1/;
                $release =~ s/-/::/g;
                push(@edges, [$release, $_->{_source}->{module}]);
            }
    
            $result = $es->scroll(
                scroll_id   => $result->{_scroll_id},
                scroll      => '5m'
            );
        }
        my $res = $pr->getPagerankOfNodes (listOfEdges => \@edges);
        my @sort = sort { $res->{$b} <=> $res->{$a} } keys %$res;
        for(1..10) {
            my $mod = shift @sort;
            print $mod, " ", $res->{$mod}, $/;
        }
}