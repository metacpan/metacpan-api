package MetaCPAN::Tests::PSGI;

use Test::More;
use Test::Routine;

use MetaCPAN::Server::Test qw( app test_psgi );

sub psgi_app {
    my ( $self, $sub ) = @_;
    my @result;

    test_psgi(
        app    => app(),
        client => sub {
            @result = $sub->(@_);
        },
    );

    return $result[0];
}

1;
