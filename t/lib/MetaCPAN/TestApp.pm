package MetaCPAN::TestApp;

use strict;
use warnings;

use LWP::ConsoleLogger::Easy qw( debug_ua );
use MetaCPAN::Server::Test qw( app );
use Moose;
use Plack::Test::Agent;

has _test_agent => (
    is      => 'ro',
    isa     => 'Plack::Test::Agent',
    handles => ['get'],
    lazy    => 1,
    default => sub {
        my $self = shift;
        return Plack::Test::Agent->new(
            app => app(),
            ua  => $self->_user_agent,

            #            server => 'HTTP::Server::Simple',
        );
    },
);

# set a server value above if you want to see debugging info
has _user_agent => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    default => sub {
        my $ua = LWP::UserAgent->new;
        debug_ua($ua);
        return $ua;
    },
);

__PACKAGE__->meta->make_immutable();
1;
