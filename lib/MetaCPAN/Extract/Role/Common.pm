package MetaCPAN::Extract::Role::Common;

use Moose::Role;

has 'debug' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'minicpan' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

sub file2mod {

    my $self        = shift;
    my $name = shift;

    $name =~ s{\Alib\/}{};
    $name =~ s{\.(pod|pm)\z}{};
    $name =~ s{\/}{::}gxms;

    return $name;
}

sub _build_debug {

    my $self = shift;
    return $ENV{'DEBUG'} || 0;

}

sub _build_minicpan {

    my $self = shift;
    return $ENV{'MINICPAN'} || "$ENV{'HOME'}/minicpan";

}

1;
