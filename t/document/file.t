use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::File;
my %stub = (
    author       => 'Foo',
    path         => 'bar',
    release      => 'release',
    distribution => 'foo',
    name         => 'module.pm',
);

{
    my $content = <<'END';
package Foo;
use strict;

=head1 NAME
X<Foo> X<Bar>

MyModule - mymodule1 abstract

  not this

=pod

bla

=cut

more perl code

=head1 SYNOPSIS

more pod
more

even more

END

    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     content      => \$content );

    is( $file->abstract, 'mymodule1 abstract' );
    is($file->documentation, 'MyModule' );
    is_deeply( $file->pod_lines, [ [ 3, 12 ], [ 18, 6 ] ] );
    is( $file->sloc, 3 );
    is( $file->slop, 11 );
}
{
    my $content = <<'END';

=head1 NAME

MyModule

END

    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     content      => \$content );

    is( $file->abstract, undef );
    is( $file->slop, 2 );
    is( $file->documentation, 'MyModule');
}
{
    my $content = <<'END';
#!/bin/perl

=head1 NAME
 
Script - a command line tool
 
=head1 VERSION
 
Version 0.5.0

END

    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     content      => \$content );

    is( $file->abstract, 'a command line tool' );
    is( $file->documentation, 'Script' );
}
{
    my $content = <<'END';
#$Id: Config.pm,v 1.5 2008/09/02 13:14:18 kawas Exp $

=head1 NAME

=for html foobar

 MOBY::Config.pm - An object B<containing> information about how to get access to teh Moby databases, resources, etc. from the 
mobycentral.config file

=cut


=head2 USAGE

=cut

package MOBY::Config;

END

    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     path         => 't/bar/bat.t',
                                     module       => { name => 'MOBY::Config' },
                                     content_cb   => sub { \$content } );

    is( $file->abstract,
'An object containing information about how to get access to teh Moby databases, resources, etc. from the mobycentral.config file'
    );
    is( $file->module->[0]->hide_from_pause(${$file->content}), 0, 'indexed' );
    is( $file->documentation, 'MOBY::Config.pm' );
    is( $file->level, 2);
}

{
    my $content = <<'END';
package
  Number::Phone::NANP::ASS;

# numbering plan at http://www.itu.int/itudoc/itu-t/number/a/sam/86412.html

use strict;

use base 'Number::Phone::NANP';

use Number::Phone::Country qw(noexport);

our $VERSION = 1.1;

my $cache = {};

# NB this module doesn't register itself, the NANP module should be
# used and will load this one as necessary

=head1 NAME

Number::Phone::NANP::AS

AS-specific methods for Number::Phone

=cut

1;
END
    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     module => [{ name => 'Number::Phone::NANP::ASS', version => 1.1 }],
                                     content_cb   => sub { \$content } );
    is( $file->sloc, 8, '8 lines of code' );
    is( $file->slop, 4, '4 lines of pod' );
    is( $file->module->[0]->hide_from_pause($content), 1, 'not indexed' );
    is( $file->abstract, 'AS-specific methods for Number::Phone' );
    is( $file->documentation, 'Number::Phone::NANP::AS' );
    is_deeply( $file->pod_lines, [ [ 18, 7 ] ], 'correct pod_lines' );
    is( $file->module->[0]->version_numified, 1.1, 'numified version has been calculated');
}

{
    my $content = <<'END';
package # hide the package from PAUSE
    Perl6Attribute;

=head1 NAME

C<Perl6Attribute> -- An example attribute metaclass for Perl 6 style attributes

END
    my $file =
      MetaCPAN::Document::File->new( %stub,
                                     name         => 'Perl6Attribute.pod',
                                     module => [{ name => 'main', version => 1.1 }],
                                     content_cb   => sub { \$content } );
    is($file->documentation, 'Perl6Attribute');
    is($file->abstract, 'An example attribute metaclass for Perl 6 style attributes');
}

{
    my $content = <<'END';
package Foo;

__DATA__

=head1 NAME

Foo -- An example attribute metaclass for Perl 6 style attributes

END
    my $file =
      MetaCPAN::Document::File->new( %stub,
                                       name         => 'Foo.pod',
                                     content_cb   => sub { \$content } );
    is($file->documentation, 'Foo', 'POD in __DATA__ section');
}

done_testing;
