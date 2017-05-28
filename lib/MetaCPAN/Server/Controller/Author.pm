package MetaCPAN::Server::Controller::Author;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

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
    my $st = $file->{_source}
        || single_valued_arrayref_to_scalar( $file->{fields} );
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

# /author/by_user/USER_ID
sub by_user : Path('by_user') : Args(1) {
    my ( $self, $c, $user ) = @_;
    my $data = $self->model($c)->raw->by_user($user);
    $data or return;
    $c->stash($data);
}

# /author/by_user?user=USER_ID1&user=USER_ID2...
sub by_users : Path('by_user') : Args(0) {
    my ( $self, $c ) = @_;
    my @users = $c->req->param('user');
    return unless @users;
    my $data = $self->model($c)->raw->by_user( \@users );
    $data or return;
    $c->stash($data);
}

1;
