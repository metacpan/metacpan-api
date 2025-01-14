package MetaCPAN::Query;
use Moose;

use Module::Runtime              qw( require_module );
use Module::Pluggable::Object    ();
use MooseX::Types::ElasticSearch qw( ES );

has es => (
    is       => 'ro',
    required => 1,
    isa      => ES,
    coerce   => 1,
);

my @plugins = Module::Pluggable::Object->new(
    search_path => [__PACKAGE__],
    max_depth   => 3,
    require     => 0,
)->plugins;

for my $class (@plugins) {
    require_module($class);
    my $name = $class->can('name') && $class->name
        or next;

    my $in  = "_in_$name";
    my $gen = "_gen_$name";

    has $in => (
        is       => 'ro',
        init_arg => $name,
        weak_ref => 1,
    );

    has $gen => (
        is       => 'ro',
        init_arg => undef,
        lazy     => 1,
        default  => sub {
            my $self = shift;
            $class->new(
                es    => $self->es,
                query => $self,
            );
        },
    );

    no strict 'refs';
    *$name = sub { $_[0]->$in // $_[0]->$gen };
}

1;
