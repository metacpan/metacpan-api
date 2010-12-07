package MetaCPAN::Role::Common;

use Moose::Role;

has 'cpan' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

has 'debug' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'es' => ( is => 'rw', lazy_build => 1 );

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

sub _build_cpan {

    my $self = shift;
    return $ENV{'MINICPAN'} || "$ENV{'HOME'}/minicpan";

}

sub _build_es {

    my $e = ElasticSearch->new(
        servers   => 'localhost:9200',
        transport => 'http',         # default 'http'
                                         #trace_calls => 'log_file',
    );

}

1;
