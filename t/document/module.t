use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::Module;
use MetaCPAN::Document::File;
use File::stat;
use Digest::SHA1;
use DateTime;
use MetaCPAN::Util;

my $content = <<'END';
package
  Number::Phone::NANP::AS;

# numbering plan at http://www.itu.int/itudoc/itu-t/number/a/sam/86412.html

use strict;

use base 'Number::Phone::NANP';

use Number::Phone::Country qw(noexport);

our $VERSION = 1.1;

my $cache = {};

# NB this module doesn't register itself, the NANP module should be
# used and will load this one as necessary

=head1 NAME

Number::Phone::NANP::AS - AS-specific methods for Number::Phone

=cut

1;
END
my $file =
  MetaCPAN::Document::File->new( author       => 'Foo',
                                 path         => 'bar',
                                 release      => 'release',
                                 distribution => 'foo',
                                 name         => 'module.pm',
                                 stat         => {},
                                 content_cb   => sub { \$content } );

my $module =
  MetaCPAN::Document::Module->new( file         => $file,
                                   name         => 'Api.pm',
                                   distribution => 'CPAN-API',
                                   author       => 'PERLER',
                                   release      => 'CPAN-API-0.1',
                                   date         => DateTime->now );

my $id = MetaCPAN::Util::digest(qw(PERLER CPAN-API-0.1 Api.pm));
is( $module->id, $id );
is( $module->abstract, 'AS-specific methods for Number::Phone' );
is( $module->file->indexed, 0 );

done_testing;
