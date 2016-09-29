package MetaCPAN::Server::Role::ES::Query;

use strict;
use warnings;

use Moose::Role;

use Ref::Util qw( is_arrayref );

sub es_query_by_filter {
    my ( $self, $c, $filter ) = @_;
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

    my $res = $self->model($c)->raw->filter($filter);
    $res = $res->fields( \@fields ) if @fields;
    $res = $res->sort( \@sort )     if @sort;
    $res = $res->size($size)->all;

    $c->stash($res);
}

sub es_query_by_key {
    my ( $self, $c, $key, $vals ) = @_;
    my @vals = is_arrayref $vals ? @{$vals} : $vals;
    $self->es_query_by_filter( $c,
        { bool => { should => [ map +{ term => { $key => $_ } }, @vals ] } }
    );
}

no Moose::Role;
1;
