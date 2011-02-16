use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::File;

use MetaCPAN::Pod::Lines;

{
    my $content = <<'END';
package Foo;
use strict;

=head1 NAME

MyModule - mymodule1 abstract

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
      MetaCPAN::Document::File->new( author       => 'Foo',
                                     path         => 'bar',
                                     release      => 'release',
                                     distribution => 'foo',
                                     name         => 'module.pm',
                                     stat         => {},
                                     content      => \$content );

    is( $file->abstract, 'mymodule1 abstract bla' );
    is( $file->module,   'MyModule' );
    is_deeply( $file->toc,
               [  { text => 'NAME',     leaf => \1 },
                  { text => 'SYNOPSIS', leaf => \1 } ] );
    is_deeply( $file->pod_lines, [ [ 3, 9 ], [ 15, 6 ] ] );
    is( $file->sloc, 3 );
}
{
    my $content = <<'END';
=head1 NAME

MyModule

END

    my $file =
      MetaCPAN::Document::File->new( author       => 'Foo',
                                     path         => 'bar',
                                     release      => 'release',
                                     distribution => 'foo',
                                     name         => 'module.pm',
                                     stat         => {},
                                     content      => \$content );

    is( $file->abstract, '' );
    is( $file->module,   'MyModule' );
    is_deeply( $file->toc, [ { text => 'NAME', leaf => \1 } ] );
}
{
    my $content = <<'END';
#$Id: Config.pm,v 1.5 2008/09/02 13:14:18 kawas Exp $

=head1 NAME

MOBY::Config.pm - An object containing information about how to get access to teh Moby databases, resources, etc. from the 
mobycentral.config file

=cut


=head2 USAGE
END

    my $file =
      MetaCPAN::Document::File->new( author       => 'Foo',
                                     path         => 'bar',
                                     release      => 'release',
                                     distribution => 'foo',
                                     name         => 'module.pm',
                                     stat         => {},
                                     content      => \$content );

    is( $file->abstract,
'An object containing information about how to get access to teh Moby databases, resources, etc. from the mobycentral.config file'
    );
    is( $file->module, 'MOBY::Config.pm' );
    is_deeply( $file->toc,
               [
                  {  text     => 'NAME',
                     children => [ { text => 'USAGE', leaf => \1 } ] } ] );
}

{
    my $content = <<'END';
package Number::Phone::NANP::AS;

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

=head1 DESCRIPTION

This class implements AS-specific methods for Number::Phone.  It is
a subclass of Number::Phone::NANP, which is in turn a subclass of
Number::Phone.  Number::Phone::NANP sits in the middle because all
NANP countries can share some significant chunks of code.  You should
never need to C<use> this module directly, as C<Number::Phone::NANP>
will load it automatically when needed.

=head1 SYNOPSIS

    use Number::Phone::NANP;
    
    my $phone_number = Number::Phone->new('+1 684 633 0001');
    # returns a Number::Phone::NANP::AS object
    
=head1 METHODS

The following methods from Number::Phone are overridden:

=over 4

=item regulator

Returns information about the national telecomms regulator.

=cut

sub regulator { return 'ASTCA, http://www.samoatelco.com/ ???'; }

=back

=head1 BUGS/FEEDBACK

Please report bugs by email, including, if possible, a test case.             

I welcome feedback from users.

=head1 LICENCE

You may use, modify and distribute this software under the same terms as
perl itself.

=head1 AUTHOR

David Cantrell E<lt>david@cantrell.org.ukE<gt>

Copyright 2005

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

    is( $file->sloc, 8 );
    is_deeply( $file->pod_lines, [ [ 17, 31 ], [ 51, 20 ] ] );
}

done_testing;
