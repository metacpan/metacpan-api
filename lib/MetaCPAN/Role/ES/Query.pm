package MetaCPAN::Role::ES::Query;

use strict;
use warnings;

use Moose::Role;

use Ref::Util qw( is_arrayref is_coderef );

# queries by given terms and values
sub es_by_terms_vals {
    my ( $self, %args ) = @_;
    my $filter = _filter_from_args( \%args );
    return $self->es_by_filter( %args, filter => $filter );
}

# queries by given filter
sub es_by_filter {
    my ( $self, %args ) = @_;
    my $filter = delete $args{filter};
    my $res    = $self->raw->filter($filter);
    return $self->es_query_res( %args, res => $res );
}

# applies generic 'size', 'sort' & 'fields' to
# query result
sub es_query_res {
    my ( $self, %args ) = @_;
    my ( $req, $res, $cb ) = @args{qw< req res cb >};
    my $params = $req->parameters;

    my $size = $params->{size} // 5000;
    my $from = 0;
    $params->{page} and $from = ( $params->{page} - 1 ) * $size;

    my @fields;
    if ( $params->{fields} ) {
        @fields = $req->read_param('fields');
    }

    my @sort;
    if ( $params->{sort} ) {
        @sort
            = map { /^(.*):((?:desc|asc))$/ ? { $1 => { order => $2 } } : $_ }
            $req->read_param('sort');
    }

    $res = $res->fields( \@fields ) if @fields;
    $res = $res->sort( \@sort )     if @sort;
    $res = $res->from($from)        if $from;
    $res = $res->size($size)->all;
    $res = $cb->($res) if $cb and is_coderef($cb);

    return $res;
}

sub _filter_from_args {
    my $args = shift;

    my $constant_score = delete $args->{constant_score};
    return +{
        constant_score => +{
            filter => _filter_from_args($constant_score)
        }
        }
        if $constant_score;

    my ( $should, $must ) = delete @{$args}{qw< should must >};
    my $filter
        = $should
        ? _filter_bool_terms_values( should => $should )
        : _filter_bool_terms_values( must   => $must );

    return $filter;
}

sub _filter_key_multi_vals { +{ terms => {@_} } }

sub _filter_term_key_vals {
    my ( $k, $v ) = @_;
    return (
        is_arrayref $v
        ? _filter_key_multi_vals( $k, $v )
        : +{ term => { $k => $v } }
    );
}

sub _filter_bool_terms_values {
    my ( $op, $kv ) = @_;
    return +{
        bool => {
            $op =>
                [ map { _filter_term_key_vals( $_, $kv->{$_} ) } keys %$kv ]
        }
    };
}

no Moose::Role;
1;
