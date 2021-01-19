package MetaCPAN::API;

=head1 DESCRIPTION

This is the API web server interface.

    # On vagrant VM
    ./bin/run morbo bin/api.pl

    # Display information on jobs in queue
    ./bin/run bin/api.pl minion job -s

To run the api web server, run the following on one of the servers:

    # Run the daemon on a local port (tunnel to display on your browser)
    ./bin/run bin/api.pl daemon

=cut

use Mojo::Base 'Mojolicious';

use Config::ZOMG ();
use File::Temp   ();
use List::Util qw( any );
use MetaCPAN::Script::Runner ();
use Search::Elasticsearch    ();
use Try::Tiny qw( catch try );

has es => sub {
    return Search::Elasticsearch->new(
        client => '2_0::Direct',
        ( $ENV{ES} ? ( nodes => [ $ENV{ES} ] ) : () ),
    );
};

sub startup {
    my $self = shift;

    unless ( $self->config->{config_override} ) {
        $self->config(
            Config::ZOMG->new(
                local_suffix => $ENV{HARNESS_ACTIVE} ? 'testing' : 'local',
                name         => 'metacpan_server',
                path         => $self->home->to_string,
            )->load
        );
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

    $self->plugin('MetaCPAN::API::Plugin::Model');
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
            $job->fail(
                {
                    message => $_,
                    @warnings ? ( warnings => \@warnings ) : (),
                }
            );
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

    $admin->get('home')->to('admin#home')->name('admin-home');
    $admin->post('enqueue')->to('queue#enqueue')->name('enqueue');
    $admin->post('search-identities')->to('admin#search_identities')
        ->name('search-identities');
    $admin->get('index-release')->to('queue#index_release')
        ->name('index-release');
    $admin->get('identity-search-form')->to('admin#identity_search_form')
        ->name('identity_search_form');

    $self->plugin( 'Minion::Admin' => { route => $admin->any('/minion') } );
    $self->plugin(
        'OpenAPI' => { url => $self->home->rel_file('root/static/v1.yml') } );

# This route is for when nginx gets updated to no longer strip the `/v1` path.
# By retaining the `/v1` path the OpenAPI spec is picked up and passed
# through Mojolicous.  The `rewrite` parameter is stripping the `/v1` before
# it is passed to Catalyst allowing the previous logic to be followed.
    $self->plugin(
        MountPSGI => {
            '/v1'   => $self->home->child('app.psgi')->to_string,
            rewrite => 1
        }
    );

# XXX Catch cases when `v1` has been stripped by nginx until migration is complete
# XXX then this path can be removed.
    $self->plugin(
        MountPSGI => { '/' => $self->home->child('app.psgi')->to_string } );

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
                $c->session( github_username => $username );
                $c->redirect_to('/admin');
                return;
            }
            $c->redirect_to( $self->config->{front_end_url} );
        },
    );

    $self->plugin(
        'Web::Auth',
        module      => 'Google',
        key         => $oauth->{google}->{key},
        secret      => $oauth->{google}->{secret},
        user_info   => 1,
        on_finished => sub {
            my ( $c, $access_token, $account_info ) = @_;
            my $username = $account_info->{login};
            $c->session( is_logged_in    => 1 );
            $c->session( google_username => $username );
            $c->redirect_to( $self->config->{front_end_url} );
        },
    );

    $self->plugin(
        'Web::Auth',
        module      => 'Twitter',
        key         => $oauth->{twitter}->{key},
        secret      => $oauth->{twitter}->{secret},
        user_info   => 1,
        on_finished => sub {
            my ( $c, $access_token, $access_secret, $account_info ) = @_;
            my $username = $account_info->{screen_name};
            $c->session( is_logged_in     => 1 );
            $c->session( twitter_username => $username );
            $c->redirect_to( $self->config->{front_end_url} );
        },
    );
}

1;
