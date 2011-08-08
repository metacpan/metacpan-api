package MetaCPAN::Script::Pagerank;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Graph::Centrality::Pagerank;

sub run {
    my $self = shift;
    my $es   = $self->es;
    my $pr   = Graph::Centrality::Pagerank->new();
    my @edges;
    my $modules = $self->get_recent_modules;
    my $scroll  = $es->scrolled_search(
        index => $self->index->name,
        type  => 'release',
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    and => [
                        {   term =>
                                { 'release.dependency.phase' => 'runtime' }
                        },
                        { term => { status => 'latest' } },
                    ]
                }
            }
        },
        scroll => '5m',
        size   => 1000,
    );
    die $scroll->total;

    while ( my $release = $scroll->next ) {
        foreach my $dep ( @{ $_->{_source}->{dependency} || [] } ) {
            next if ( $dep->{phase} ne 'runtime' );
            my $dist = $modules->{ $dep->{name} };
            next unless ($dist);
            push( @edges, [ $release->{_source}->{name}, $dist ] );
        }
    }
    my $res = $pr->getPagerankOfNodes( listOfEdges => \@edges );
    my @sort = sort { $res->{$b} <=> $res->{$a} } keys %$res;
    for ( 1 .. 10 ) {
        my $mod = shift @sort;
        print $mod, " ", $res->{$mod}, $/;
    }
}

sub get_recent_modules {
    my $self   = shift;
    my $scroll = $self->es->scrolled_search(
        index => $self->index->name,
        type  => 'file',
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    and => [
                        { term => { 'file.status'         => 'latest' } },
                        { term => { 'file.module.indexed' => \1 } },
                    ]
                }
            }
        },
        size   => 1000,
        fields => [qw(distribution file.module.name)],
        scroll => '1m',
    );
    warn $scroll->total;
    my $result;
    while ( my $file = $scroll->next ) {
        my $modules = $file->{fields}->{'module.name'};
        $modules = [$modules] unless ( ref $modules );
        foreach my $module (@$modules) {
            $result->{$module} = $file->{fields}->{release};
        }
    }
    return $result;
}

1;
