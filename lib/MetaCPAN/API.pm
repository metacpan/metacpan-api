package MetaCPAN::API;

=head1 DESCRIPTION

This is the API Minion server.

    # Display information on jobs in queue
    ./bin/run bin/api.pl minion job -s

=cut

use Mojo::Base 'Mojolicious';

use File::Temp               ();
use MetaCPAN::Script::Runner ();
use Try::Tiny                qw( catch try );
use MetaCPAN::Server::Config ();

sub startup {
    my $self = shift;

    unless ( $self->config->{config_override} ) {
        $self->config( MetaCPAN::Server::Config::config() );
    }

    die 'need secret' unless $self->config->{secret};

    $self->secrets( [ $self->config->{secret} ] );

    $self->plugin( Minion => $self->_build_db_params );

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
            $job->fail( {
                message => $_,
                @warnings ? ( warnings => \@warnings ) : (),
            } );
        };
    }
}

sub _build_db_params {
    my $self = shift;

    my $db_params;
    if ( $ENV{HARNESS_ACTIVE} ) {
        my $file = File::Temp->new( UNLINK => 1, SUFFIX => '.db' );
        return { SQLite => 'sqlite:' . $file };
    }

    die "Unable to determine dsn from configuration"
        unless $self->config->{minion_dsn};

    if ( $self->config->{minion_dsn} =~ /^postgresql:/ ) {
        return { Pg => $self->config->{minion_dsn} };
    }

    if ( $self->config->{minion_dsn} =~ /^sqlite:/ ) {
        return { SQLite => $self->config->{minion_dsn} };
    }

    die "Unsupported Database in dsn: " . $self->config->{minion_dsn};
}

1;
