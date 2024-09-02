package Catalyst::Authentication::Store::Proxy;

# ABSTRACT: Delegates authentication logic to the user object
use Moose;
use Catalyst::Utils           ();
use MetaCPAN::Types::TypeTiny qw( HashRef Str );

has user_class => (
    is       => 'ro',
    required => 1,
    isa      => Str,
    lazy     => 1,
    builder  => '_build_user_class'
);
has handles => ( is => 'ro', isa => HashRef );
has config  => ( is => 'ro', isa => HashRef );
has app     => ( is => 'ro', isa => 'ClassName' );
has realm   => ( is => 'ro' );

sub BUILDARGS {
    my ( $class, $config, $app, $realm ) = @_;
    my $handles = {
        map { $_ => $_ } qw(from_session for_session find_user),
        %{ $config->{handles} || {} },
        app   => $app,
        realm => $realm,
    };
    return {
        handles => $handles,
        app     => $app,
        realm   => $realm,
        $config->{user_class} ? ( user_class => $config->{user_class} ) : (),
        config => $config
    };
}

sub BUILD {
    my $self = shift;
    Catalyst::Utils::ensure_class_loaded( $self->user_class );
    return $self;
}

sub _build_user_class {
    shift->app . "::User";
}

sub new_object {
    my ( $self, $c ) = @_;
    return $self->user_class->new( $self->config, $c );
}

sub from_session {
    my ( $self, $c, $frozenuser ) = @_;
    my $user     = $self->new_object( $self->config, $c );
    my $delegate = $self->handles->{from_session};
    return $user->$delegate( $c, $frozenuser );
}

sub for_session {
    my ( $self, $c, $user ) = @_;
    my $delegate = $self->handles->{for_session};
    return $user->$delegate($c);
}

sub find_user {
    my ( $self, $authinfo, $c ) = @_;
    my $user     = $self->new_object( $self->config, $c );
    my $delegate = $self->handles->{find_user};
    return $user->$delegate( $authinfo, $c );

}

1;

=head1 SYNOPSIS

 package MyApp::User;
 use Moose;
 extends 'Catalyst::Authentication::User';
 
 sub from_session {
     my ($self, $c, $id) = @_;
 }
 
 sub for_session  {
     my ($self, $c) = @_;
 }
 
 sub find_user    {
     my ($self, $authinfo, $c) = @_;
 }
 
 ...
 
 MyApp->config(
     'Plugin::Authentication' => {
        default => {
            credential => {
                class         => 'Password',
                password_type => 'none',
            },
            store => { class => 'Proxy' }
        }
    }
 );

=head1 DESCRIPTION

This module makes it much easier to implement a custom
authenication store. It delegates all the necessary
method for user retrieval and session storage to a custom
user class.

=head1 CONFIGURATION

=head2 user_class

Methods are delegated to this user class. It defaults to
C<MyApp::User>, where C<MyApp> is the name of you application.
The follwing methods have to be implemented in that class
additionally to those mentioned in
L<Catalyst::Authentication::User>:

=over 4

=item C<< find_user ($c, $authinfo) >>

The second argument C<$authinfo> is whatever was passed
to C<< $c->authenticate >>. If the user can be authenticated
using C<$authinfo> it has to return a new object of type
C<MyApp::User> or C<undef>.

=item C<< from_session ($c, $id) >>

Given a session C<id>, this method returns an instance of
the matching C<MyApp::User>.

=item C<< for_session ($c) >>

This has to return a unique identifier of the user object
which will be used as second parameter to L</from_session>.

=back

=head2 handles

 MyApp->config(
     'Plugin::Authentication' => {
        default => {
            credential => { ... },
            store => {
                class => 'Proxy',
                handles => {
                    find_user => 'find',
                },
            }
        }
    }
 );

Change the name of the authentication methods to something
else.

=head1 SEE ALSO

=over 4

=item L<Catalyst::Authentication::Store::DBIx::Class> operates in the same way.

=item L<Catalyst::Authentication::User> explains what a user class should look like.

=item L<Catalyst::Plugin::Authentication::Internals> gives a good introduction
into the authentication internals.

=back
