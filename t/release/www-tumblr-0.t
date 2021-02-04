use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use Test::More;

test_release(
    {
        name         => 'WWW-Tumblr-0',
        distribution => 'WWW-Tumblr',
        author       => 'LOCAL',
        authorized   => 1,
        first        => 1,
        version      => '0',

        provides => [ 'WWW::Tumblr', ],

        tests => 1,

        extra_tests => sub {
            my ($self) = @_;
            my $tests = $self->data->tests;

            my $content = $self->file_content('lib/WWW/Tumblr.pm');
            like $content, qr/\$VERSION = ('?)0\1;/, 'version is zero';
        },
    }
);

done_testing;

