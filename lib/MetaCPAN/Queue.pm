package MetaCPAN::Queue;

=head1 DESCRIPTION

This is not a web app.  It's purely here to manage the API's release indexing
queue.

    # On vagrant VM
    ./bin/run morbo bin/queue.pl

=cut

use Mojo::Base 'Mojolicious';

use MetaCPAN::Queue::Helper;

sub startup {
    my $self = shift;

    # for Mojo cookies, which we won't be needing
    $self->secrets( ['veni vidi vici'] );

    my $helper = MetaCPAN::Queue::Helper->new;
    $self->plugin( Minion => $helper->backend );
}

1;
