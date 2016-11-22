package MetaCPAN::Server::Role::ES::Query;

use strict;
use warnings;

use Moose::Role;

use Ref::Util qw( is_arrayref is_coderef );

# queries by given terms and values
sub es_by_terms_vals {
    my ( $self, %args ) = @_;
    my ( $c, $cb, $should, $must ) = @args{qw< c cb should must >};
    my $filter
        = $should
        ? _filter_bool_terms_values( should => $should )
        : _filter_bool_terms_values( must   => $must );
    return $self->es_by_filter( c => $c, cb => $cb, filter => $filter );
}

# queries by given filter
sub es_by_filter {
    my ( $self, %args ) = @_;
    my ( $c, $cb, $filter, $_model ) = @args{qw< c cb filter model >};
    my $model = $_model ? $c->model($_model) : $self->model($c);
    my $res = $model->raw->filter($filter);
    return $self->es_query_res( c => $c, cb => $cb, res => $res );
}

# applies generic 'size', 'sort' & 'fields' to
# query result
sub es_query_res {
    my ( $self, %args ) = @_;
    my ( $c, $cb, $res ) = @args{qw< c cb res >};
    my $params = $c->req->parameters;

    my $size = $params->{size} || 5000;

    my @fields;
    if ( $params->{fields} ) {
        @fields = $c->req->read_param('fields');
    }

    my @sort;
    if ( $params->{sort} ) {
        @sort
            = map { /^(.*):((?:desc|asc))$/ ? { $1 => { order => $2 } } : $_ }
            $c->req->read_param('sort');
    }

    $res = $res->fields( \@fields ) if @fields;
    $res = $res->sort( \@sort )     if @sort;
    $res = $res->size($size)->all;
    $res = $cb->($res) if $cb and is_coderef($cb);

    return $res;
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
