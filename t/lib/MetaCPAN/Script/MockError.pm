package MetaCPAN::Script::MockError;

use Moose;
use Exception::Class ('MockException');
use MetaCPAN::Types::TypeTiny qw( Bool Int Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has arg_error_message => (
    init_arg      => 'message',
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'mock an Error Message',
);

has arg_error_code => (
    init_arg      => 'error',
    is            => 'ro',
    isa           => Int,
    default       => -1,
    documentation => 'mock an Exit Code',
);

has arg_die => (
    init_arg      => 'die',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'mock an Exception',
);

has arg_handle_error => (
    init_arg      => 'handle_error',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'mock a handled error',
);

has arg_exception => (
    init_arg      => 'exception',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'mock an Exception Class',
);

sub exit_with_die {
    my $self = $_[0];

    if ( $self->arg_error_message ne '' ) {
        die( $self->arg_error_message );
    }
    else {
        die "mock bare die() call";
    }
}

sub exit_with_error {
    my $self = $_[0];

    if ( $self->arg_error_message ne '' ) {
        $self->handle_error( $self->arg_error_message, 1 );
    }
    else {
        $self->handle_error( "mock bare die() call", 1 );
    }
}

sub throw_exception {
    my $self = $_[0];

    if ( $self->arg_error_message ne '' ) {
        MockException->throw( error => $self->arg_error_message );
    }
    else {
        MockException->throw( error => "mock an Execption Class" );
    }
}

sub run {
    my $self = shift;

    $self->exit_code( $self->arg_error_code )
        if ( $self->arg_error_code != -1 );

    $self->exit_with_error
        if ( $self->arg_handle_error );

    $self->exit_with_die if ( $self->arg_die );

    $self->throw_exception if ( $self->arg_exception );

    $self->print_error( $self->arg_error_message )
        if ( $self->arg_error_message ne '' );

# The run() method is expected to communicate Success to the superior execution level
    return ( $self->exit_code == 0 );
}

1;
