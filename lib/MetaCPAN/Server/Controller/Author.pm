package MetaCPAN::Server::Controller::Author;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';
with 'MetaCPAN::Server::Role::ES::Query';

__PACKAGE__->config(
    relationships => {
        release => {
            type    => ['Release'],
            self    => 'pauseid',
            foreign => 'author',
        },
        favorite => {
            type    => ['Favorite'],
            self    => 'user',
            foreign => 'user',
        }
    }
);

# https://fastapi.metacpan.org/v1/author/LLAP
sub get : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->add_author_key($id);
    $c->cdn_max_age('1y');

    my $file = $self->model($c)->raw->get($id);
    if ( !defined $file ) {
        $c->detach( '/not_found', ['Not found'] );
    }
    my $st = $file->{_source} || $file->{fields};
    if ( $st and $st->{pauseid} ) {
        $st->{release_count}
            = $c->model('CPAN::Release')
            ->aggregate_status_by_author( $st->{pauseid} );

        my ( $id_2, $id_1 ) = $id =~ /^((\w)\w)/;
        $st->{links} = {
            cpan_directory => "http://cpan.org/authors/id/$id_1/$id_2/$id",
            backpan_directory =>
                "https://cpan.metacpan.org/authors/id/$id_1/$id_2/$id",
            cpants => "http://cpants.cpanauthors.org/author/$id",
            cpantesters_reports =>
                "http://cpantesters.org/author/$id_1/$id.html",
            cpantesters_matrix => "http://matrix.cpantesters.org/?author=$id",
            metacpan_explorer =>
                "https://explorer.metacpan.org/?url=/author/$id",
        };
    }
    $c->stash($st)
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

# endpoint: /author/search?key=<key>[&fields=<csv_fields>][&sort=<csv_sort>][&size=N]
sub search : Path('search') : Args(0) {
    my ( $self, $c ) = @_;
    my $key    = $c->req->parameters->{key};
    my $filter = +{
        bool => {
            should => [
                {
                    match => {
                        'name.analyzed' =>
                            { query => $key, operator => 'and' }
                    }
                },
                {
                    match => {
                        'asciiname.analyzed' =>
                            { query => $key, operator => 'and' }
                    }
                },
                { match => { 'pauseid'    => uc($key) } },
                { match => { 'profile.id' => lc($key) } },
            ]
        }
    };

    my $cb = sub {
        my $res = shift;
        return +{
            results => [
                map { +{ %{ $_->{_source} }, id => $_->{_id} } }
                    @{ $res->{hits}{hits} }
            ],
            total => $res->{hits}{total} || 0,
            took => $res->{took}
        };
    };

    $self->es_by_filter( c => $c, filter => $filter, cb => $cb );
}

# endpoint: /author/by_id?id=<csv_author_ids>[&fields=<csv_fields>][&sort=<csv_sort>][&size=N]
sub by_id : Path('by_id') : Args(0) {
    my ( $self, $c ) = @_;
    my @ids = map {uc} split /,/ => $c->req->parameters->{id};
    $self->es_by_key_vals( c => $c, key => 'pauseid', vals => \@ids );
}

# endpoint: /author/by_user?user=<csv_user_ids>[&fields=<csv_fields>][&sort=<csv_sort>][&size=N]
sub by_user : Path('by_user') : Args(0) {
    my ( $self, $c ) = @_;
    my @users = split /,/ => $c->req->parameters->{user};
    $self->es_by_key_vals( c => $c, key => 'user', vals => \@users );
}

1;
