package MetaCPAN::Admin;

=head1 DESCRIPTION

This is not a web app.  It's purely here to manage the API's release indexing
queue.

    # On vagrant VM
    ./bin/run morbo bin/queue.pl

    # Display information on jobs in queue
    ./bin/run bin/queue.pl minion job

To run the minion admin web interface, run the following on one of the servers:

    # Run the daemon on a local port (tunnel to display on your browser)
    ./bin/run bin/queue.pl daemon -l http://*:5002

=cut

use Mojo::Base 'Mojolicious';

use List::Util qw( any );
use MetaCPAN::Queue::Helper  ();
use MetaCPAN::Script::Runner ();
use Try::Tiny qw( catch try );

sub startup {
    my $self = shift;

    die 'need secret' unless $ENV{MOJO_SECRET};

    $self->secrets( [ $ENV{MOJO_SECRET} ] );

    my $helper = MetaCPAN::Queue::Helper->new;
    $self->plugin( Minion => $helper->backend );
    $self->minion->add_task(
        index_release => $self->_gen_index_task_sub('release') );

    $self->minion->add_task(
        index_latest => $self->_gen_index_task_sub('latest') );

    $self->minion->add_task(
        index_favorite => $self->_gen_index_task_sub('favorite') );

    $self->_maybe_set_up_routes;
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
    };
}

sub _maybe_set_up_routes {
    my $self = shift;
    return unless $ENV{GITHUB_KEY};

    $self->plugin(
        'Web::Auth',
        module      => 'Github',
        key         => $ENV{GITHUB_KEY},
        secret      => $ENV{GITHUB_SECRET},
        on_finished => sub {
            my ( $c, $access_token, $account_info ) = @_;
            my $login = $account_info->{login};
            if ( $self->_is_admin($login) ) {
                $c->session( username => $login );
                $c->redirect_to('/admin');
                return;
            }
            return $c->render(
                text => "$login is not authorized to access this application",
                status => 403
            );
        },
    );

    my $r     = $self->routes;
    my $admin = $r->under(
        '/admin' => sub {
            my $c = shift;
            return 1 if $self->_is_admin( $c->session('username') );
            $c->redirect_to('/auth/github/authenticate');
            return 0;
        }
    );

    $admin->get('home')->('admin#home')->name('admin-home');
    $admin->post('enqueue')->to('queue#enqueue')->name('enqueue');
    $admin->post('search-identities')->to('admin#search_identities')
        ->name('search-identities');
    $admin->get('index-release')->to('queue#index_release')
        ->name('index-release');
    $admin->get('identity-search-form')->to('admin#identity_search_form')
        ->name('identity_search_form');

    $self->plugin( 'Minion::Admin' => { route => $admin->any('/minion') } );
}

sub _is_admin {
    my $self = shift;
    my $username
        = shift || ( $ENV{HARNESS_ACTIVE} ? $ENV{FORCE_ADMIN_AUTH} : () );
    return 0 unless $username;

    my @admins = (
        'haarg', 'jberger', 'mickeyn', 'oalders',
        'ranguard', 'reyjrar', 'ssoriche',
        $ENV{HARNESS_ACTIVE} ? 'tester' : (),
    );

    return any { $username eq $_ } @admins;
}

1;
