package MetaCPAN::Script::Restart;

use MetaCPAN::Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    shift->es->restart(
        delay => '5s'    # optional
    );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan restart

=cut
