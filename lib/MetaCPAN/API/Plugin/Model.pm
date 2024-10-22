package MetaCPAN::API::Plugin::Model;

use Mojo::Base 'Mojolicious::Plugin';

use Carp ();

# Models from the catalyst app
use MetaCPAN::Query::Search ();

# New models
use MetaCPAN::API::Model::Cover    ();
use MetaCPAN::API::Model::Download ();
use MetaCPAN::API::Model::User     ();

has app => sub { Carp::croak 'app is required' }, weak => 1;

has download => sub {
    my $self = shift;
    return MetaCPAN::API::Model::Download->new( es => $self->app->es );
};

has search => sub {
    my $self = shift;
    return MetaCPAN::Query::Search->new(
        es         => $self->app->es,
        index_name => 'cpan',
    );
};

has user => sub {
    my $self = shift;
    return MetaCPAN::API::Model::User->new( es => $self->app->es );
};

has cover => sub {
    my $self = shift;
    return MetaCPAN::API::Model::Cover->new( es => $self->app->es );
};

sub register {
    my ( $plugin, $app, $conf ) = @_;
    $plugin->app($app);

    # cached models
    $app->helper( 'model.download' => sub { $plugin->download } );
    $app->helper( 'model.search'   => sub { $plugin->search } );
    $app->helper( 'model.user'     => sub { $plugin->user } );
    $app->helper( 'model.cover'    => sub { $plugin->cover } );
}

1;

