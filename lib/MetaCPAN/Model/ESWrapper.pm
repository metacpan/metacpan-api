package MetaCPAN::Model::ESWrapper;
use strict;
use warnings;

use MetaCPAN::Types::TypeTiny qw( ES );

sub new {
    my ( $class, $es ) = @_;
    if ( $es->api_version le '6_0' ) {
        return $es;
    }
    return bless { es => ES->assert_coerce($es) }, $class;
}

sub DESTROY { }

sub AUTOLOAD {
    my $sub  = our $AUTOLOAD =~ s/.*:://r;
    my $self = shift;
    $self->{es}->$sub(@_);
}

sub _args {
    my $self = shift;
    if ( @_ == 1 ) {
        return ( $self, %{ $_[0] } );
    }
    return ( $self, @_ );
}

sub count {
    my ( $self, %args ) = &_args;
    delete $args{type};
    $self->{es}->count(%args);
}

sub get {
    my ( $self, %args ) = &_args;
    delete $args{type};
    $self->{es}->get(%args);
}

sub delete {
    my ( $self, %args ) = &_args;
    delete $args{type};
    $self->{es}->delete(%args);
}

sub search {
    my ( $self, %args ) = &_args;
    delete $args{type};
    $self->{es}->search(%args);
}

sub scroll_helper {
    my ( $self, %args ) = &_args;
    delete $args{type};
    $self->{es}->scroll_helper(%args);
}

1;
