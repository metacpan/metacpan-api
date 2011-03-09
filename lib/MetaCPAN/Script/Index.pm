package MetaCPAN::Script::Index;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use MetaCPAN::Script::Mapping;

has [qw(create delete recreate mapping)] => ( isa => 'Bool', is => 'rw' );

sub run {
    my $self = shift;
    my ( undef, $index ) = @{ $self->extra_argv };
    $index ||= 'cpan';
    my $es = $self->es;
    my $arg = { index => $index,
                defn  => {
                          analysis => {
                                        analyzer => {
                                                     lowercase => {
                                                         type      => 'custom',
                                                         tokenizer => 'keyword',
                                                         filter => 'lowercase'
                                                     } } } } };
    if ( $self->create ) {
        log_info { "Creating index $index" };
        $es->create_index($arg);
    } elsif ( $self->delete ) {
        log_info { "Deleting index $index" };
        $es->delete_index( index => $index );
    } elsif ( $self->recreate ) {
        log_info { "Recreating index $index" };
        $es->delete_index( index => $index );
        $es->create_index($arg);
    }
    if ( $self->mapping ) {
        local @ARGV = qw(mapping);
        MetaCPAN::Script::Runner->run;
    }
}

__PACKAGE__->meta->make_immutable;
