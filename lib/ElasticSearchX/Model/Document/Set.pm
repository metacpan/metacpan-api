package ElasticSearchX::Model::Document::Set;
use strict;
use warnings;

use MetaCPAN::Model::Hacks;

no warnings 'redefine';

our %query_override;
my $_build_query = \&_build_query;
*_build_query = sub {
    my $query = $_build_query->(@_);
    %$query = ( %$query, %query_override, );
    return $query;
};

our %qs_override;
my $_build_qs = \&_build_qs;
*_build_qs = sub {
    my $qs = $_build_qs->(@_);
    %$qs = ( %$qs, %qs_override, );
    return $qs;
};

my $delete = \&delete;
*delete = sub {
    local %qs_override    = ( search_type => 'query_then_fetch' );
    local %query_override = ( sort        => '_doc' );
    return $delete->(@_);
};

my $get = \&get;
*get = sub {
    my ( $self, $args, $qs ) = @_;
    if ( $self->es->api_version eq '2_0' ) {
        goto &$get;
    }
    my %qs = %{ $qs || {} };
    if ( my $fields = $self->fields ) {
        $qs{_source} = $fields;
        local $self->{fields};
        return $get->( $self, $args, \%qs );
    }
    goto &$get;
};

1;
