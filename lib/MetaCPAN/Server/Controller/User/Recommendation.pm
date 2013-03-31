package MetaCPAN::Server::Controller::User::Recommendation;

use Moose;
BEGIN { extends 'Catalyst::Controller::REST' }

sub auto : Private {
    my ($self, $c) = @_;
    unless($c->user->looks_human) {
        $self->status_forbidden($c, message => 'please complete the turing test');
        return 0;
    } else {
        return 1;
    }
}

sub index : Path : ActionClass('REST') {
}

sub index_PUT {
    my ( $self, $c, $module, $relation, $other_module ) = @_;

    # TODO let's chain those suckers at some point
    die unless $relation eq 'instead_of';

    my $pause    = $c->stash->{pause};
    my $req      = $c->req;

    # user can only recommend one module over
    # another one
    my $old = $c->model('CPAN::Recommendation')->mget(
        { user         => $c->user->id,
            instead_of   => $other_module, }
    );

    $old->delete( { refresh => 1 } ) if $old;

    my $recommendation = $c->model('CPAN::Recommendation')->put(
        {   user         => $c->user->id,
            module       => $module,
            $relation    => $other_module,
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for(
            join( '/',
                '/recommendation', $recommendation->user, $recommendation->module,
                'instead_of', $recommendation->instead_of )
        ),
        entity => $recommendation->meta->get_data($recommendation)
    );
}

sub index_DELETE {
    my ( $self, $c, $module, $relation, $other_module ) = @_;
    my $rec = $c->model('CPAN::Recommendation')
        ->get( { user => $c->user->id, module => $module, $relation =>
                $other_module } )
        or $self->status_not_found( $c, message => 'Entity could not be found' );      
        
    $rec->delete( { refresh => 1 } );
    $self->status_ok( $c,
        entity => $rec->meta->get_data($rec) );
}
1;
