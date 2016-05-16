package MetaCPAN::Queue::Monitor;

use Moo;

extends 'Mojolicious';

use CHI;
use feature qw( say );

use MetaCPAN::Queue::Helper;
use Minion;

=head1 NAME

  MetaCPAN::Queue::Monitor

=head1 SYNOPSIS

    use MetaCPAN::Queue::Monitor;

    my $monitor = MetaCPAN::Queue::Monitor->new({

      graph_title => 'Active Workers',
      graph_info => "What's happening in the Minion queue",
      fields => [ 'inactive_workers', 'active_workers' ],

    });

    $monitor->run();

=head1 DESCRIPTION

This spits out the relevant information for a munin monitoring
if the 1st ARGV is 'config' then the config is displayed,
otherwise the actual data

=cut

has graph_title => (
    is       => 'rw',
    required => 1,
);

has graph_info => (
    is       => 'rw',
    required => 1,
);

has fields => (
    is       => 'rw',
    required => 1,
);

sub cache {
    CHI->new(
        driver   => 'File',
        root_dir => '/tmp/',
    );
}

has config_mode => (
    is      => 'rw',
    default => sub { defined $ARGV[0] && $ARGV[0] eq 'config' ? 1 : 0 },
);

sub run {
    my ( $self, $args ) = @_;

    if ( $self->config_mode ) {

        # Tell Munin how to config this output
        say sprintf 'graph_title %s', $self->graph_title;
        say sprintf 'graph_info %s',  $self->graph_info;
        say 'graph_vlabel count';
        say 'graph_category metacpan_api';

        for my $field ( @{ $self->fields } ) {
            my $label = $field;
            $label =~ s/_/ /g;
            say sprintf '%s.label %s', $field, ucfirst($label);
        }

        exit;

    }
    else {

        # Print out the results
        my $stats = $self->_queue_stats();

        for my $field ( @{ $self->fields } ) {

            my $value = $stats->{$field} // 0;
            say sprintf '%s.value %s', $field, $value;

        }

    }

}

# Fetch the stats from the cache or DB
sub _queue_stats {
    my $self = $_[0];

    my $stats_cache = 'stats_cache';

    my $stats;
    unless ( $stats = $self->cache->get($stats_cache) ) {

        my $helper  = MetaCPAN::Queue::Helper->new;
        my $backend = $helper->backend;

        my $minion = Minion->new( %{$backend} );
        my $stats  = $minion->stats;

        $self->cache->set( $stats_cache, $stats, 0 );    # 1 min cache

    }

    return $stats;

}

1;
