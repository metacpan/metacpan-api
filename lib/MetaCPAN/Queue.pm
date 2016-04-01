package MetaCPAN::Queue;

=head1 DESCRIPTION

This is not a web app.  It's purely here to manage the API's release indexing
queue.

    # On vagrant VM
    ./bin/run morbo bin/queue.pl

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

    $self->minion->add_task(
        index_release => sub {
            my ( $job, @args ) = @_;

            # @args could be ( '--latest', '/path/to/release' );
            unshift @args, 'release';

            # Runner expects to have been called via CLI
            local @ARGV = @args;
            try {
                my $release = MetaCPAN::Script::Runner->run(@args);
            }
            catch {
                warn $_;
                $job->fail( { message => $_ } );
            };
        }
    );
}

1;
