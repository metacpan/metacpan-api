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
    is_deeply( $file->toc, [ { text => 'NAME', leaf => \1 }, { text => 'SYNOPSIS', leaf => \1 } ] );
    is_deeply( $file->pod_lines, [[3, 9], [15, 6]]);
    is( $file->sloc, 3);
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

done_testing;
