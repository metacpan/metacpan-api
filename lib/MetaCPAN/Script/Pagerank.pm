package MetaCPAN::Script::Pagerank;

use strict;
use warnings;

use Graph::Centrality::Pagerank;
use Log::Contextual qw( :log );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;
    my $es   = $self->es;
    my $pr   = Graph::Centrality::Pagerank->new();
    my @edges;
    my $modules = $self->get_recent_modules;

    log_info {'Loading dependencies ...'};

    my $scroll = $es->scroll_helper(
        index => $self->index->name,
        type  => 'release',
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    and => [
                        {
                            term =>
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

    log_info { $scroll->total, " recent releases found with dependencies" };

    my $i = 0;
    while ( my $release = $scroll->next ) {
        foreach my $dep ( @{ $release->{_source}->{dependency} || [] } ) {
            next if ( $dep->{phase} ne 'runtime' );
            my $dist = $modules->{ $dep->{module} };
            next unless ($dist);
            $i++;
            push( @edges, [ $release->{_source}->{name}, $dist ] );
        }
    }
    log_info {
        "Calculating PageRankg with taking $i dependencies into account";
    };
    my $res = $pr->getPagerankOfNodes( listOfEdges => \@edges );
    my @sort = sort { $res->{$b} <=> $res->{$a} } keys %$res;
    for ( 1 .. 500 ) {
        my $mod = shift @sort;
        print $mod, " ", $res->{$mod}, $/;
    }
}

sub get_recent_modules {
    my $self = shift;
    log_info {"Mapping modules to releases ..."};
    my $scroll = $self->es->scroll_helper(
        index => $self->index->name,
        type  => 'file',
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    and => [
                        { term => { 'file.status'            => 'latest' } },
                        { term => { 'file.module.indexed'    => \1 } },
                        { term => { 'file.module.authorized' => \1 } },
                    ]
                }
            }
        },
        size   => 1000,
        fields => [
            qw(release distribution file.module.authorized file.module.indexed file.module.name)
        ],
        scroll => '1m',
    );
    log_info { $scroll->total, " modules found" };
    my $result;
    while ( my $file = $scroll->next ) {
        next if ( $file->{fields}->{distribution} eq 'perl' );
        my $modules;
        my $data;
        for (qw(name authorized indexed)) {
            $data->{$_} = $file->{fields}->{"module.$_"};
            $data->{$_} = [ $data->{$_} ] unless ( ref $data->{$_} );
        }
        for ( my $i = 0; $i < @{ $data->{name} }; $i++ ) {
            next
                unless ( $data->{indexed}->[$i] eq "true"
                && $data->{authorized}->[$i] eq "true" );
            $result->{ $data->{name}->[$i] } = $file->{fields}->{release};
        }
    }
    return $result;
}

__PACKAGE__->meta->make_immutable;
1;
