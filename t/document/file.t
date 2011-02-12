use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::File;
use File::stat;

my $content = <<'END';
=head1 NAME

MyModule - mymodule1 abstract

END


my $file = MetaCPAN::Document::File->new( author => 'Foo', path => 'bar', release => 'release', name => 'module.pm', stat => File::stat->new, content => \$content );

is($file->abstract, 'mymodule1 abstract');
is_deeply($file->toc, [{ text => 'NAME', leaf => \1 }]);


done_testing;