package ElasticSearch::Document::Trait::Attribute;
use Moose::Role;

has property => ( is => 'ro', isa => 'Bool', default => 1 );

has id => ( is => 'ro', isa => 'Bool|ArrayRef', default => 0 );
has index  => ( is => 'ro', lazy_build => 1 );
has boost  => ( is => 'ro', isa        => 'Num', default => 1.0 );
has store  => ( is => 'ro', isa        => 'Str', default => 'yes' );
has type   => ( is => 'ro', isa        => 'Str', lazy_build => 1 );
has parent => ( is => 'ro', isa        => 'Bool', default => 0 );
has analyzer => ( is => 'ro', isa => 'Str' );

sub _build_type {
    my $self = shift;
    my $tc = $self->type_constraint ? $self->type_constraint->name : 'Str';
    my %map = ( Int      => 'integer',
                Str      => 'string',
                DateTime => 'date',
                Num      => 'float',
                Bool     => 'boolean',
                Undef    => 'null',
                HashRef  => 'object',
                ArrayRef => 'string' );
    return $map{$tc} || 'string';
}

sub _build_index {
    my $self = shift;
    return $self->type eq 'string' ? $self->analyzer ? 'analyzed' : 'not_analyzed' : undef;
}

sub is_property { shift->property }

sub es_properties {
    my $self = shift;
    my $props;
    if ( $self->type eq 'string' && $self->index eq 'analyzed' ) {
        $props = { type   => 'multi_field',
                   fields => {
                               $self->name => { store => $self->store,
                                                index => 'analyzed',
                                                boost => $self->boost,
                                                type  => $self->type,
                                                analyzer => $self->analyzer || 'standard',
                               },
                               raw => { store => $self->store,
                                        index => 'not_analyzed',
                                        boost => $self->boost,
                                        type  => $self->type
                               },
                   } };
    } else {
        $props = { store => $self->store,
                   $self->index ? ( index => $self->index ) : (),
                   boost => $self->boost,
                   type  => $self->type,
                   $self->analyzer ? ( analyzer => $self->analyzer ) : (), };
    }
    if ( $self->has_type_constraint && $self->type_constraint->name =~ /Ref/ ) {
        $props->{dynamic} = \0;
    }
    return $props;
}

before _process_options => sub {
    my ( $self, $name, $options ) = @_;
    $options->{required} = 1    unless ( exists $options->{required} );
    $options->{is}       = 'ro' unless ( exists $options->{is} );
    %$options = ( builder => '_build_es_id', lazy => 1, %$options )
      if ( $options->{id} && ref $options->{id} eq 'ARRAY' );
};

1;
