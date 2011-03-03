package ElasticSearch::Document::Trait::Class;
use Moose::Role;
use List::Util ();
use Carp;

has bulk_size => ( isa => 'Int', default => 10, is => 'rw' );

sub build_map {
    my $self = shift;
    my $props =
      { map { $_->name => $_->es_properties }
        sort { $a->name cmp $b->name }
        grep { $_->is_property }
        map  { $self->get_attribute($_) } $self->get_attribute_list };
    return { index            => 'cpan',
             _source          => { compress => \1 },
             type             => lc( $self->short_name ),
             properties       => $props, };
}

sub short_name {
    my $self = shift;
    ( my $name = $self->name ) =~ s/^.*:://;
    return lc($name);
}

sub get_id_attribute {
    my $self = shift;
    my ( $id, $more ) =
      grep { $_->id }
      map  { $self->get_attribute($_) } $self->get_attribute_list;
    croak "Cannot have more than one id field on a class" if ($more);
    return $id;
}

sub put_mapping {
    my ( $self, $es ) = @_;
    $es->put_mapping( $self->build_map );
}

sub bulk_index {
    my ( $self, $es, $bulk, $force ) = @_;
    while ( @$bulk > $self->bulk_size || $force ) {
        my @step = splice( @$bulk, 0, $self->bulk_size );
        my @data =
          map { { create => { $_->_index } } } map { $self->name->new(%$_) } @step;
        
        $es->bulk(@data);
        undef $force unless (@$bulk);
    }
}

sub get_data {
    my ( $self, $instance ) = @_;
    return {
        map {
                $_->name => $_->has_deflator
              ? $_->deflate($instance)
              : $_->get_value($instance)
          } grep {
            $_->is_property && ( $_->has_value($instance) || $_->is_required )
          } map {
            $self->get_attribute($_)
          } $self->get_attribute_list };
}

1;
