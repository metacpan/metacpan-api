package MetaCPAN::Plack::Release;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;
use MetaCPAN::Util;

sub type { 'release' }

sub query {
    shift;
    return { query  => { match_all => {} },
       filter => {
            and => [
                { term => { 'release.distribution' => shift } },
                { term => { status                 => 'latest' } } ] },
     sort => [ { date => 'desc' } ],
     size => 1 };
}

sub handle {
    my ( $self, $req ) = @_;
    my ( undef, $index, @args ) = split( "/", $req->path );
    my $digest;
    if(@args == 2) {
        $digest = MetaCPAN::Util::digest( @args );
        return $self->get_source($req->clone( PATH_INFO => join("/", $index, $digest ) ) );
    } elsif(@args == 1) {
        return $self->get_first_result($req);
    }
}

1;