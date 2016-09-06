package MetaCPAN::Role::Fastly;

# Direct copy of MetaCPAN::Web::Role::Fastly, just different namespace

use Moose::Role;
use Net::Fastly;
use Carp;

with 'CatalystX::Fastly::Role::Response';
with 'MooseX::Fastly::Role';

=head1 NAME

MetaCPAN::Web::Role::Fastly - Methods for fastly intergration

=head1 SYNOPSIS

  use Catalyst qw/
    +MetaCPAN::Web::Role::Fastly
    /;

=head1 DESCRIPTION

This role includes L<CatalystX::Fastly::Role::Response> and
L<MooseX::Fastly::Role>.

It also adds some methods.

Finally just before C<finalize> it will add the content type
as surrogate keys and perform a purge of anything needing
to be purged

=head1 METHODS

=head2 $c->purge_surrogate_key('BAR');

Try to use on of the more specific methods below if possible.

=cut

=head2 $c->add_author_key('Ether');

Always upper cases

=cut

sub add_author_key {
    my ( $c, $author ) = @_;

    $c->add_surrogate_key( $c->_format_auth_key($author) );
}

=head2 $c->purge_author_key('Ether');

=cut

sub purge_author_key {
    my ( $c, $author ) = @_;

    $c->purge_surrogate_key( $c->_format_auth_key($author) );
}

=head2 $c->add_dist_key('Moose');

Upper cases, removed I<:> and I<-> so that
Foo::bar and FOO-Bar becomes FOOBAR,
not caring about the edge case of there
ALSO being a Foobar package, they'd
all just get purged.

=cut

sub add_dist_key {
    my ( $c, $dist ) = @_;

    $c->add_surrogate_key( $c->_format_dist_key($dist) );
}

=head2 $c->purge_dist_key('Moose');

=cut

sub purge_dist_key {
    my ( $c, $dist ) = @_;

    $c->add_surrogate_key( $c->_format_dist_key($dist) );
}

=head2 $c->purge_cpan_distnameinfos(\@list_of_distnameinfo_objects);

Using this array reference of L<CPAN::DistnameInfo> objects,
the cpanid and dist name are extracted and used to build a list
of keys to purge, the purge happens from within this method.

All other purging requires `finalize` to be implimented so it
can be wrapped with a I<before> and called.

=cut

#cdn_purge_cpan_distnameinfos
sub purge_cpan_distnameinfos {
    my ( $c, $dist_list ) = @_;

    my %purge_keys;
    foreach my $dist ( @{$dist_list} ) {

        croak "Must be CPAN::DistnameInfo"
            unless UNIVERSIAL::isa('CPAN::DistnameInfo');

        $purge_keys{ $c->_format_auth_key( $dist->cpanid ) } = 1;    # "GBARR"
        $purge_keys{ $c->_format_dist_key( $dist->dist ) }
            = 1;    # "CPAN-DistnameInfo"

    }

    my @unique_to_purge = keys %purge_keys;

    # Now run with this list
    $c->cdn_purge_now( { keys => \@unique_to_purge } );

}

has _surrogate_keys_to_purge => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => ArrayRef [Str],
    default => sub { [] },
    handles => {
        purge_surrogate_key          => 'push',
        has_surrogate_keys_to_purge  => 'count',
        surrogate_keys_to_purge      => 'elements',
        join_surrogate_keys_to_purge => 'join',
    },
);

before 'finalize' => sub {
    my $c = shift;

    if ( $c->cdn_max_age ) {

        # We've decided to cache on Fastly, so throw fail overs
        # if there is an error at origin
        $c->cdn_stale_if_error('30d');
    }

    my $content_type = lc( $c->res->content_type || 'none' );

    $c->add_surrogate_key( 'content_type=' . $content_type );

    $content_type =~ s/\/.+$//;    # text/html -> 'text'
    $c->add_surrogate_key( 'content_type=' . $content_type );

    # Some action must have triggered a purge
    if ( $c->has_surrogate_keys_to_purge ) {

        # Something changed, means we need to purge some keys
        my @keys = $c->surrogate_keys_to_purge();

        $c->cdn_purge_now( { keys => \@keys, } );
    }

};

=head2 datacenters()

=cut

sub datacenters {
    my ($c) = @_;
    my $net_fastly = $c->cdn_api();
    return unless $net_fastly;

    # Uses the private interface as fastly client doesn't
    # have this end point yet
    my $datacenters = $net_fastly->client->_get('/datacenters');
    return $datacenters;
}

sub _format_dist_key {
    my ( $c, $dist ) = @_;

    $dist = uc($dist);
    $dist =~ s/:/-/g;    #

    return 'dist=' . $dist;
}

sub _format_auth_key {
    my ( $c, $author ) = @_;

    $author = uc($author);
    return 'author=' . $author;
}

1;
