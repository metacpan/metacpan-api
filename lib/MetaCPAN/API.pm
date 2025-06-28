package MetaCPAN::API;

=head1 DESCRIPTION

This is the API Minion server.

    # Display information on jobs in queue
    ./bin/run bin/api.pl minion job -s

=cut

use Mojo::Base 'Mojolicious';

use File::Temp               ();
use List::Util               qw( any );
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

    $self->static->paths( [ $self->home->child('root') ] );

    $self->plugin( Minion => $self->_build_db_params );

    $self->minion->add_task(
        index_release => $self->_gen_index_task_sub('release') );

    $self->minion->add_task(
        index_latest => $self->_gen_index_task_sub('latest') );

    $self->minion->add_task(
        index_favorite => $self->_gen_index_task_sub('favorite') );

    $self->_set_up_routes;
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

sub _set_up_routes {
    my $self = shift;

    my $r = $self->routes;

    my $admin = $r->under(
        '/admin' => sub {
            my $c        = shift;
            my $username = $c->session('github_username');
            if ( $self->_is_admin($username) ) {
                return 1;
            }

            # Direct non-admins away from the app
            elsif ($username) {
                $c->redirect_to('https://metacpan.org');
                return 0;
            }

            # This is possibly a logged out admin
            $c->redirect_to('/auth/github/authenticate');
            return 0;
        }
    );

    $self->_set_up_oauth_routes;
    $self->plugin( 'Minion::Admin' => { route => $admin->any('/minion') } );
}

sub _is_admin {
    my $self     = shift;
    my $username = $ENV{HARNESS_ACTIVE} ? $ENV{FORCE_ADMIN_AUTH} : shift;
    return 0 unless $username;

    my @admins = (
        'haarg',    'jberger', 'mickeyn', 'oalders',
        'ranguard', 'reyjrar', 'ssoriche',
        $ENV{HARNESS_ACTIVE} ? 'tester' : (),
    );

    return any { $username eq $_ } @admins;
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

sub _set_up_oauth_routes {
    my $self = shift;

    my $oauth = $self->config->{oauth};

    # We could do better DRY here, but it might be more complicated than it's
    # worth

    $self->plugin(
        'Web::Auth',
        module      => 'Github',
        key         => $oauth->{github}->{key},
        secret      => $oauth->{github}->{secret},
        user_info   => 1,
        on_finished => sub {
            my ( $c, $access_token, $account_info ) = @_;
            my $username = $account_info->{login};
            $c->session( is_logged_in    => 1 );
            $c->session( github_username => $username );
            if ( $self->_is_admin($username) ) {
                $c->redirect_to('/admin');
                return;
            }
            $c->redirect_to( $self->config->{front_end_url} );
        },
    );
}

1;
