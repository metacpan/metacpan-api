package MetaCPAN::Model::Hacks;
use strict;
use warnings;

sub import {
    my ( $caller, $caller_file ) = caller;

    my $file = $caller      =~ s{::}{/}gr . '.pm';
    my $dir  = $caller_file =~ s{/\Q$file\E\z}{}r;
    local @INC = grep $_ ne $dir, @INC;
    my $inc;
    {
        local $INC{$file};
        delete $INC{$file};
        require $file;
        $inc = $INC{$file};
    }
    delete $INC{$file};
    $INC{$file} = $inc;
    return;
}

1;
