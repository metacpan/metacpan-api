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
            = $self->_get_author_release_status_counts( $c, $st->{pauseid} );
    }
    $c->stash($st)
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub _get_author_release_status_counts {
    my ( $self, $c, $pauseid ) = @_;
    my %ret;
    for my $status (qw< cpan backpan latest >) {
        $ret{$status} = $c->model('CPAN::Release')->filter(
            {
                and => [
                    { term => { author => $pauseid } },
                    { term => { status => $status } }
                ]
            }
            )->count
            || 0;
    }
    $ret{'backpan-only'} = delete $ret{'backpan'};
    return \%ret;
}

1;
