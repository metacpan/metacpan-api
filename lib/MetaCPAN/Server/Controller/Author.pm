package MetaCPAN::Server::Controller::Author;

use strict;
use warnings;

use Moose;

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

sub get : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;
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

1;
