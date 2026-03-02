package MetaCPAN::Query::Role::Common;
use Moose::Role;

use MetaCPAN::Types qw( ES );

has es => (
    is       => 'ro',
    required => 1,
    isa      => ES,
    coerce   => 1,
);

sub name {
    my $self  = shift;
    my $class = ref $self || $self;

    $class =~ /^MetaCPAN::Query::([^:]+)$/
        or return undef;
    return lc $1;
}

has _in_query => (
    is       => 'ro',
    init_arg => 'query',
    weak_ref => 1,
);

has _gen_query => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my $self = shift;
        my $name = $self->name;

        require MetaCPAN::Query;
        MetaCPAN::Query->new(
            es => $self->es,
            ( $name ? ( $name => $self ) : () ),
        );
    },
);

sub query { $_[0]->_in_query // $_[0]->_gen_query }

1;
