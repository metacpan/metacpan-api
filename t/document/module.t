use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::Module;
use MetaCPAN::Document::File;
use File::stat;
use Digest::SHA1;
use DateTime;
use MetaCPAN::Util;

{
    my $content = <<'END';
package
 Number::Phone::NANP::AS;

=head1 NAME

Number::Phone::NANP::AS - AS-specific methods for Number::Phone
END
    my $file =
      MetaCPAN::Document::File->new( author       => 'Foo',
                                     path         => 'bar',
                                     release      => 'release',
                                     distribution => 'foo',
                                     name         => 'module.pm',
                                     content_cb   => sub { \$content } );

    my $module =
      MetaCPAN::Document::Module->new( file         => $file,
                                       name         => 'Number::Phone::NANP::AS',
                                       distribution => 'CPAN-API',
                                       author       => 'PERLER',
                                       release      => 'CPAN-API-0.1',
                                       date         => DateTime->now );

    my $id = MetaCPAN::Util::digest(qw(PERLER CPAN-API-0.1 Number::Phone::NANP::AS));
    is( $module->id,            $id );
    is( $module->abstract,      'AS-specific methods for Number::Phone' );
    is( $module->file->indexed, 0 );
    is( $module->file->module, 'Number::Phone::NANP::AS' );
}

{
    my $content = <<'END';
use strict;
package Number::Phone::NANP::AS;
1;
END
    my $file =
      MetaCPAN::Document::File->new( author       => 'Foo',
                                     path         => 'bar',
                                     release      => 'release',
                                     distribution => 'foo',
                                     name         => 'module.pm',
                                     content_cb   => sub { \$content } );

    my $module =
      MetaCPAN::Document::Module->new( file         => $file,
                                       name         => 'Number::Phone::NANP::AS',
                                       distribution => 'CPAN-API',
                                       author       => 'PERLER',
                                       release      => 'CPAN-API-0.1',
                                       date         => DateTime->now );

    my $id = MetaCPAN::Util::digest(qw(PERLER CPAN-API-0.1 Number::Phone::NANP::AS));
    is( $module->id,            $id );
    is( $module->file->indexed, 1 );
    is( $module->file->module, 'Number::Phone::NANP::AS' );
}

done_testing;
