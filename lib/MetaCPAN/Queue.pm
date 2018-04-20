package MetaCPAN::Queue;

=head1 DESCRIPTION

This is not a web app.  It's purely here to manage the API's release indexing
queue.

    # On vagrant VM
    ./bin/run morbo bin/queue.pl

    # Display information on jobs in queue
    ./bin/run bin/queue.pl minion job

To run the minion admin web interface, run the following on one of the servers:

    # Run the daemon on a local port (tunnel to display on your browser)
    ./bin/run bin/queue.pl daemon

=cut

use Mojo::Base 'Mojolicious';

use MetaCPAN::Queue::Helper  ();
use MetaCPAN::Script::Runner ();
use Try::Tiny qw( catch try );

sub startup {
    my $self = shift;

    # for Mojo cookies, which we won't be needing
    $self->secrets( ['veni vidi vici'] );

    my $helper = MetaCPAN::Queue::Helper->new;
    $self->plugin( Minion => $helper->backend );
    $self->plugin( 'Minion::Admin' => { route => $self->routes->any('/') } );

    $self->minion->add_task(
        index_release => $self->_gen_index_task_sub('release') );

    $self->minion->add_task(
        index_latest => $self->_gen_index_task_sub('latest') );

    $self->minion->add_task(
        index_favorite => $self->_gen_index_task_sub('favorite') );
}

sub _gen_index_task_sub {
    my ( $self, $type ) = @_;

    return sub {
        my ( $job, @args ) = @_;

        my @warnings;
        local $SIG{__WARN__} = sub {
            push @warnings, $_[0];
            warn $_[0];
        };

        # @args could be ( '--latest', '/path/to/release' );
        unshift @args, $type;

        # Runner expects to have been called via CLI
        local @ARGV = @args;
        try {
            MetaCPAN::Script::Runner->run(@args);
            $job->finish( @warnings ? { warnings => \@warnings } : () );
        }
        catch {
            warn $_;
            $job->fail(
                {
                    message => $_,
                    @warnings ? ( warnings => \@warnings ) : (),
                }
            );
        };
        }
}

1;
