package MetaCPAN::Role::HasRogueDistributions;

use Moose::Role;

use MetaCPAN::Types::TypeTiny qw( ArrayRef );

has rogue_distributions => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub {
        [
            qw(
                Bundle-Everything
                kurila
                perl-5.005_02+apache1.3.3+modperl
                perlbench
                perl_debug
                perl_mlb
                pod2texi
                spodcxx
            )
        ];
    },
);

no Moose::Role;
1;
