package MetaCPAN::Tests::PSGI;
use Test::Routine;
use Test::More;

use MetaCPAN::Server::Test;

sub psgi_app {
    my ( $self, $sub ) = @_;
    my @result;
    my $wantarray = wantarray;

    test_psgi app, sub {
        defined $wantarray
            ? $wantarray
                ? ( @result = $sub->(@_) )
                : ( $result[0] = $sub->(@_) )
            : do { $sub->(@_); 1 };
        return;
    };

    return $wantarray ? @result : $result[0] if defined $wantarray;
    return;
}

1;
