package MetaCPAN::Queue;

=head1 DESCRIPTION

This is not a web app.  It's purely here to manage the API's release indexing
queue.

    # On vagrant VM
    ./bin/run morbo bin/queue.pl

    # Display information on jobs in queue
    ./bin/run bin/queue.pl minion job

=cut

use Mojo::Base 'Mojolicious';

use MetaCPAN::Queue::Helper  ();
use MetaCPAN::Script::Runner ();
use Try::Tiny qw( catch try );
use Cpanel::JSON::XS qw( encode_json );

sub startup {
    my $self = shift;

    # for Mojo cookies, which we won't be needing
    $self->secrets( ['veni vidi vici'] );

    my $helper = MetaCPAN::Queue::Helper->new;
    $self->plugin( Minion => $helper->backend );

    $self->minion->add_task(
        index_release => sub {
            my ( $job, @args ) = @_;

            my @warnings;
            local $SIG{__WARN__} = sub {
                push @warnings, $_[0];
                warn $_[0];
            };

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

            $job->finish( { warnings => encode_json( \@warnings ) } ) or die;
        }
    );
}

1;
