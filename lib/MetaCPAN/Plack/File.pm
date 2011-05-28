package MetaCPAN::Plack::File;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;
use MetaCPAN::Util;

sub type { 'file' }

sub query {
    my ($self, $distribution, @path) = @_;
    my $path = join('/', @path);
    warn $path;
    return { query  => { match_all => {} },
       filter => {
            and => [
                { term => { 'file.distribution' => $distribution } },
                { term => { 'file.path' => $path } },
                { term => { status              => 'latest' } } ] },
     sort => [ { date => 'desc' } ],
     size => 1 };
}

sub get_source {
    my ( $self, $req ) = @_;
    my ( undef, $index, @args ) = split( "/", $req->path );
    my $digest;
    if ( $args[0] =~ /^[A-Za-z0-9-_]{27}$/ ) {
        $digest = $args[0];
    } else {
        $digest = MetaCPAN::Util::digest( shift @args, shift @args,
                                             join( "/", @args ) );
    }
    $self->next::method($req->clone( PATH_INFO => join("/", $index, $digest ) ) );
}

sub handle {
    my ( $self, $req ) = @_;
    my ( undef, $index, @args ) = split( "/", $req->path );
    my $digest;
    if ( @args == 1 && $args[0] =~ /^[A-Za-z0-9-_]{27}$/ ) {
        $digest = $args[0];
        return $self->get_source($req->clone( PATH_INFO => join("/", $index, $digest ) ) );
    } elsif(@args > 2) {
        $digest = MetaCPAN::Util::digest( shift @args, shift @args,
                                             join( "/", @args ) );
        return $self->get_source($req->clone( PATH_INFO => join("/", $index, $digest ) ) );
    }
    # disabled for now because /MOO/abc/abc.t can either be the file
    # abc.t in release abc of author MOO or the file abc/abc.t
    # in the latest MOO release
    #
    # elsif(@args == 2) {
    #     return $self->get_first_result($env);
    # }
}

1;
