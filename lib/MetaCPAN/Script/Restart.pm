package MetaCPAN::Script::Restart;

use strict;
use warnings;

use Moose;

with 'MetaCPAN::Role::Common', 'MooseX::Getopt';

sub run {
    shift->es->restart(

        #    nodes       => multi,
        delay => '5s'    # optional
    );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan restart

=cut
