use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;
use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    'RWSTAUNER/Pod-Examples-99',
    {
        first       => \1,
        extra_tests => \&test_files,
    }
);

sub test_files {
    my ($self) = @_;
    my $pod_files
        = $self->filter_files( { term => { mime => 'text/x-pod' } } );
    is( @$pod_files, 1, 'includes one pod file' );

    is(
        (
            grep { $_->{documentation} eq 'Pod::Examples::Spacial' }
                @$pod_files
        ),
        1,
        'parsed =head1\x20\x20NAME'
    );

    is(
        ${ $pod_files->[0]->pod },
        q[NAME Pod::Examples::Spacial DESCRIPTION An extra space between 'head1' and 'NAME'],
        'pod text'
    );
}

done_testing;
