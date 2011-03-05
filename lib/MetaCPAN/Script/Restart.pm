package MetaCPAN::Script::Restart;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use MetaCPAN;

sub run {
    shift->es->restart(

        #    nodes       => multi,
        delay => '5s'    # optional
    );
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 SYNOPSIS

 # bin/metacpan restart