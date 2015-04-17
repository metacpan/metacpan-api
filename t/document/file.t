use strict;
use warnings;

use MetaCPAN::Document::File;
use Test::More;

sub cpan_meta {
    CPAN::Meta->new(
        {
            name    => 'who-cares',
            version => 0,
        }
    );
}

sub new_file_doc {
    my %args = @_;

    my $mods = $args{module} || [];
    $mods = [$mods] unless ref($mods) eq 'ARRAY';

    my $pkg_template = <<'PKG';
package %s;
our $VERSION = 1;
PKG

    my $name = $args{name} || 'SomeModule.pm';
    my $file = MetaCPAN::Document::File->new(
        author       => 'CPANER',
        path         => 'some/path',
        release      => 'Some-Release-1',
        distribution => 'Some-Release',
        name         => $name,

        # Passing in "content" will override
        # but defaulting to package statements will help avoid buggy tests.
        content_cb => sub {
            \(
                join "\n",
                ( map { sprintf $pkg_template, $_->{name} } @$mods ),
                "\n\n=head1 NAME\n\n${name} - abstract\n\n=cut\n\n",
            );
        },

        %args,
    );
    $file->set_indexed( cpan_meta() );
    return $file;
}

sub test_attributes {
    my ( $obj, $att ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    foreach my $key ( sort keys %$att ) {
        my $got = $obj->$key;
        if ( $key eq 'pod' ) {

            # Dereference scalar to compare strings.
            $got = $$got;
        }
        is_deeply $got, $att->{$key}, $key;
    }
}

subtest 'helper' => sub {
    my $file = new_file_doc( module => { name => 'Foo::Bar' }, );

    is $file->module->[0]->indexed, 1, 'Regular package name indexed';
};

subtest 'basic' => sub {
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

    my $file = new_file_doc( content => \$content );

    is( $file->abstract,      'mymodule1 abstract' );
    is( $file->documentation, 'MyModule' );
    is_deeply( $file->pod_lines, [ [ 3, 12 ], [ 18, 6 ] ] );
    is( $file->sloc, 3 );
    is( $file->slop, 11 );

    is(
        ${ $file->pod },
        q[NAME MyModule - mymodule1 abstract not this bla SYNOPSIS more pod more even more],
        'pod text'
    );
};

subtest 'just pod' => sub {
    my $content = <<'END';

=head1 NAME

MyModule

END

    my $file = new_file_doc( content => \$content );

    is( $file->abstract,      undef );
    is( $file->documentation, 'MyModule' );
    test_attributes $file,
        {
        sloc      => 0,
        slop      => 2,
        pod_lines => [ [ 1, 3 ] ],
        pod       => q[NAME MyModule],
        };
};

subtest 'script' => sub {
    my $content = <<'END';
#!/bin/perl

=head1 NAME

Script - a command line tool

=head1 VERSION

Version 0.5.0

END

    my $file = new_file_doc( content => \$content );

    is( $file->abstract,      'a command line tool' );
    is( $file->documentation, 'Script' );
    test_attributes $file,
        {
        sloc      => 0,
        slop      => 4,
        pod_lines => [ [ 2, 7 ] ],
        pod => q[NAME Script - a command line tool VERSION Version 0.5.0],
        };
};

subtest 'test script' => sub {
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

    my $file = new_file_doc(
        path       => 't/bar/bat.t',
        module     => { name => 'MOBY::Config' },
        content_cb => sub { \$content }
    );

    is( $file->abstract,
        'An object containing information about how to get access to teh Moby databases, resources, etc. from the mobycentral.config file'
    );
    is(
        $file->module->[0]
            ->hide_from_pause( ${ $file->content }, $file->name ),
        0, 'indexed'
    );
    is( $file->documentation, 'MOBY::Config.pm' );
    is( $file->level,         2 );
    test_attributes $file, {
        sloc      => 1,
        slop      => 7,
        pod_lines => [ [ 2, 8 ], [ 12, 3 ] ],

   # I don't know the original intent of the pod but here are my observations:
   # * The `=for html` region has nothing in it.
   # * Podchecker considers it erroneous to have verbatim in the NAME section.
        pod =>
            q[NAME MOBY::Config.pm - An object B<containing> information about how to get access to teh Moby databases, resources, etc. from the mobycentral.config file USAGE],
    };
};

subtest 'Packages starting with underscore are not indexed' => sub {
    my $file = new_file_doc( module => { name => '_Package::Foo' } );
    is( $file->module->[0]->indexed, 0, 'Package is not indexed' );
};

subtest 'pod name/package mismatch' => sub {
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
    my $file = new_file_doc(
        module => [ { name => 'Number::Phone::NANP::ASS', version => 1.1 } ],
        content_cb => sub { \$content }
    );
    is( $file->sloc,                                   8, '8 lines of code' );
    is( $file->slop,                                   4, '4 lines of pod' );
    is( $file->module->[0]->hide_from_pause($content), 1, 'not indexed' );
    is( $file->abstract,      'AS-specific methods for Number::Phone' );
    is( $file->documentation, 'Number::Phone::NANP::AS' );
    is_deeply( $file->pod_lines, [ [ 18, 7 ] ], 'correct pod_lines' );
    is( $file->module->[0]->version_numified,
        1.1, 'numified version has been calculated' );

    is(
        ${ $file->pod },
        q[NAME Number::Phone::NANP::AS AS-specific methods for Number::Phone],
        'pod text'
    );
};

subtest 'hidden package' => sub {
    my $content = <<'END';
package # hide the package from PAUSE
    Perl6Attribute;

=head1 NAME

C<Perl6Attribute> -- An example attribute metaclass for Perl 6 style attributes

END
    my $file = new_file_doc(
        name   => 'Perl6Attribute.pod',
        module => [ { name => 'main', version => 1.1 } ],
        content_cb => sub { \$content }
    );
    is( $file->documentation, 'Perl6Attribute' );
    is( $file->abstract,
        'An example attribute metaclass for Perl 6 style attributes' );
    test_attributes $file,
        {
        sloc      => 2,
        slop      => 2,
        pod_lines => [ [ 3, 3 ], ],
        pod =>
            q[NAME "Perl6Attribute" -- An example attribute metaclass for Perl 6 style attributes],
        };
};

subtest 'pod after __DATA__' => sub {

    my $content = <<'END';
package Foo;

__DATA__

some data

=head1 NAME

Foo -- An example attribute metaclass for Perl 6 style attributes

=head1 DESCRIPTION

hot stuff

=over

=item *

Foo

=item *

Bar

=back

END
    my $file = new_file_doc(
        name       => 'Foo.pod',
        content_cb => sub { \$content }
    );
    is( $file->documentation, 'Foo', 'POD in __DATA__ section' );
    is( $file->description, 'hot stuff * Foo * Bar' );

    test_attributes $file,
        {
        sloc      => 1,
        slop      => 10,
        pod_lines => [ [ 6, 19 ], ],
        pod =>
            q[NAME Foo -- An example attribute metaclass for Perl 6 style attributes DESCRIPTION hot stuff * Foo * Bar],
        };
};

subtest 'no pod name, various folders' => sub {
    my $content = <<'END';
package Foo::Bar::Baz;

=head1 DESCRIPTION

hot stuff

=over

=item *

Foo

=item *

Bar

=back

END

    foreach my $folder ( 'pod', 'lib', 'docs' ) {
        my $file = MetaCPAN::Document::File->new(
            author       => 'Foo',
            content_cb   => sub { \$content },
            distribution => 'Foo',
            name         => 'Baz.pod',
            path         => $folder . '/Foo/Bar/Baz.pod',
            release      => 'release',
        );
        is( $file->documentation, 'Foo::Bar::Baz',
                  'Fakes a name when no name section exists in '
                . $folder
                . ' folder' );
        is( $file->abstract, undef, 'abstract undef when NAME is missing' );

        test_attributes $file,
            {
            sloc      => 1,
            slop      => 8,
            pod_lines => [ [ 2, 15 ], ],
            pod       => q[DESCRIPTION hot stuff * Foo * Bar],
            };
    }
};

# https://metacpan.org/source/SMUELLER/SelfLoader-1.20/lib/SelfLoader.pm
subtest 'pod with verbatim __DATA__' => sub {
    my $content = <<'END';
package Yo;

sub name { 42 }

=head1 Something

some paragraph ..

Fully qualified subroutine names are also supported. For example,

   __DATA__
   sub foo::bar {23}
   package baz;
   sub dob {32}

will all be loaded correctly by the B<SelfLoader>, and the B<SelfLoader>
will ensure that the packages 'foo' and 'baz' correctly have the
B<SelfLoader> C<AUTOLOAD> method when the data after C<__DATA__> is first
parsed.

=cut

"code after pod";

END

    my $file = new_file_doc(
        name       => 'Yo.pm',
        content_cb => sub { \$content }
    );

    test_attributes $file,
        {
        sloc      => 3,
        slop      => 12,
        pod_lines => [ [ 4, 17 ], ],
        pod =>
            q[Something some paragraph .. Fully qualified subroutine names are also supported. For example, __DATA__ sub foo::bar {23} package baz; sub dob {32} will all be loaded correctly by the SelfLoader, and the SelfLoader will ensure that the packages 'foo' and 'baz' correctly have the SelfLoader "AUTOLOAD" method when the data after "__DATA__" is first parsed.],
        };
};

subtest 'pod intermixed with non-pod gibberish' => sub {

    # This is totally made up in an attempt to see how we handle gibberish.
    # The decisions of the handling are open to discussion.

    my $badpod = <<BADPOD;
some\r=nonpod=ahem

=moreC<=notpod>

=head1[but no space]
BADPOD

    my $content = <<END;
package Yo;

print <<OUTSIDE_OF_POD;

$badpod

OUTSIDE_OF_POD

=head1 Start-Pod

$badpod

last-word.

=cut

"code after pod";

END

    my $file = new_file_doc(
        name       => 'Yo.pm',
        content_cb => sub { \$content }
    );

    test_attributes $file, {
        sloc      => 7,
        slop      => 6,
        pod_lines => [ [ 13, 12 ], ],

# What *should* this parse to?
# * No pod before "Start-Pod".
# * The /^some/ line starts with "some" so the whole line is just text.
# ** Pod::Simple will catch the /\r=[a-z]/ and treat it as a directive:
# *** We probably don't want to remove the line start chars (/\r?\n?/)
#     (or we'll throw off lines/blanks/etc...).
# *** If we keep the "\r" but remove the fake directive,
#     the "\r" will touch the "=ahem" and the pod document will *start*
#     and we'll get lots of text before the pod should start.
# *** So keep everything but mark them so Pod::Simple will skip them.
# ** The "\r" will count as "\s" and get squeezed into a single space.
# * So if /^=moreC/ is kept the <notpod> will retain the C.
# * When Pod::Simple sees /^head1\[/ it will start the pod document but
#   it won't be a heading, it will just be text (along with everything after)
#   which obviously was not the intention of the author.  So as long as
#   the author made a mistake and needs to fix pod:
# ** In the code, if we hide the "invalid" pod then we won't get the whole rest
#    of the file being erroneously treated as pod.
# ** Inside the pod, if we left it alone, Pod::Simple would just dump it as
#    text.  If we mark it, the same thing will happen.

        pod =>
            q{Start-Pod some =nonpod=ahem =more"=notpod" =head1[but no space] last-word.},
    };
};

subtest 'pod parsing errors are not fatal' => sub {

    my $content = <<POD;
package Foo;
use strict;

=head1 NAME

Foo - mymodule1 abstract
POD

    no warnings 'redefine';
    local *Pod::Text::parse_string_document = sub {
        die "# [fake pod error]\n";
    };

    my $file = new_file_doc(
        name       => 'Yo.pm',
        content_cb => sub { \$content }
    );

    test_attributes $file, {
        description   => undef,    # no DESCRIPTION pod
        documentation => undef,    # no pod

        # line counts are separate from the pod parser
        sloc      => 2,
        slop      => 2,
        pod_lines => [ [ 3, 3 ], ],
        pod       => q[],
    };
};

done_testing;
