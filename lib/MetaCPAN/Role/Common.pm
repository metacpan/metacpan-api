package MetaCPAN::Role::Common;

use Moose::Role;
use ElasticSearch;

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
    my @dirs = ( "$ENV{'HOME'}/CPAN", "$ENV{'HOME'}/minicpan", $ENV{'MINICPAN'} );
    foreach my $dir ( grep { defined } @dirs ) {
        return $dir if -d $dir;
    }
    die "Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN";

}

sub _build_es {

    my $e = ElasticSearch->new(
        servers   => 'localhost:9200',
        transport => 'httplite',         # default 'http'
        timeout   => 30,
        #trace_calls => 'log_file',
    );

}

1;

=pod

=head1 SYNOPSIS

Roles which should be available to all modules

=cut
