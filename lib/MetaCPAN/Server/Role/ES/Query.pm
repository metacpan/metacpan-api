package MetaCPAN::Server::Role::ES::Query;

use strict;
use warnings;

use Moose::Role;

use Ref::Util qw( is_arrayref is_coderef );

# queries by given key and values
sub es_by_key_vals {
    my ( $self, %args ) = @_;
    my ( $c, $cb, $key, $vals ) = @args{qw< c cb key vals >};
    my @vals = is_arrayref $vals ? @{$vals} : $vals;
    my $filter
        = +{
        bool => { should => [ map +{ term => { $key => $_ } }, @vals ] }
        };
    $self->es_by_filter( c => $c, cb => $cb, filter => $filter );
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
        @fields = split /,/ => $params->{fields};
    }

    my @sort;
    if ( $params->{sort} ) {
        @sort
            = map { /^(.*):((?:desc|asc))$/ ? { $1 => { order => $2 } } : $_ }
            split /,/ => $params->{sort};
    }

    $res = $res->fields( \@fields ) if @fields;
    $res = $res->sort( \@sort )     if @sort;
    $res = $res->size($size)->all;
    $res = $cb->($res) if $cb and is_coderef($cb);

    $c->stash($res);
}

no Moose::Role;
1;
