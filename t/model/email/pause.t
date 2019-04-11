use strict;
use warnings;

## no critic (Modules::RequireFilenameMatchesPackage)
package Author;

use MetaCPAN::Moose;

use MetaCPAN::Types qw( ArrayRef Str );

has name => (
    is       => 'ro',
    isa      => Str,
    init_arg => 'name',
);

has email => (
    is       => 'ro',
    isa      => ArrayRef [Str],
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;

package main;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

use Test::More;

use MetaCPAN::Model::Email::PAUSE ();

my $author = Author->new(
    name  => 'Olaf Alders',
    email => ['oalders@metacpan.org'],
);

my $email = MetaCPAN::Model::Email::PAUSE->new(
    author => $author,
    url    => URI->new('http://example.com'),
);

ok( $email->send, 'send email' );

my @messages = Email::Sender::Simple->default_transport->deliveries;
is( @messages, 1, '1 message sent' );

done_testing();
1;
