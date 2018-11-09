package MetaCPAN::API;

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

use Config::ZOMG             ();
use File::Temp               ();
use MetaCPAN::Model::Search  ();
use MetaCPAN::Script::Runner ();
use Search::Elasticsearch    ();
use Try::Tiny qw( catch try );

has es => sub {
    return Search::Elasticsearch->new(
        client => '2_0::Direct',
        nodes  => [':9200'],       #TODO config
    );
};

has model_search => sub {
    my $self = shift;
    return MetaCPAN::Model::Search->new(
        es    => $self->es,
        index => 'cpan',
    );
};

sub startup {
    my $self = shift;

    unless ( $self->config->{config_override} ) {
        $self->config(
            Config::ZOMG->new(
                name => 'metacpan_server',
                path => $self->home->to_string,
            )->load
        );
    }

    # TODO secret from config
    $self->secrets( ['veni vidi vici'] );

    if ( $ENV{HARNESS_ACTIVE} ) {
        my $file = File::Temp->new( UNLINK => 1, SUFFIX => '.db' );
        $self->plugin( Minion => { SQLite => 'sqlite:' . $file } );
    }
    else {
        $self->plugin( Minion => { Pg => $self->config->{minion_dsn} } );
    }

    $self->plugin(
        'Minion::Admin' => { route => $self->routes->any('/minion') } );
    $self->plugin(
        MountPSGI => { '/' => $self->home->child('app.psgi')->to_string } );

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
