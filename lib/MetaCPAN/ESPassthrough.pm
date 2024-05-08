package MetaCPAN::ESPassthrough;
use strict;
use warnings;

use Plack::Builder   qw(builder enable mount);
use Cpanel::JSON::XS qw(encode_json);
use Plack::Request   ();
use Moo;

extends 'Plack::Component';

has es => (
    is       => 'ro',
    required => 1,
);

my $MAX_SIZE = 5000;

my %indexes = (
    author       => 'cpan_v1_01/author',
    distribution => 'cpan_v1_01/distribution',
    favorite     => 'cpan_v1_01/favorite',
    file         => 'cpan_v1_01/file',
    mirror       => 'cpan_v1_01/mirror',
    module       => 'cpan_v1_01/file',
    package      => 'cpan_v1_01/package',
    permission   => 'cpan_v1_01/permission',
    rating       => 'cpan_v1_01/rating',
    release      => 'cpan_v1_01/release',
);

has to_app => ( is => 'lazy' );

sub _build_to_app {
    my $self = shift;
    builder {
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                if ( $env->{CONTENT_LENGTH} ) {
                    my $content_type = $env->{CONTENT_TYPE};
                    if (  !$content_type
                        || $content_type
                        =~ m{^application/x-www-form-urlencoded\b} )
                    {
                        $env = { %$env, CONTENT_TYPE => 'application/json' };
                    }
                }
                local $env->{__PACKAGE__.'.request'} = _req($env);
                return $app->($env);
            };
        };
        for my $url_base ( sort keys %indexes ) {
            my $index = $indexes{$url_base};
            $index =~ s{/(.*)}{};
            my $type = $1;
            my %args = (
                index => $index,
                defined $type ? ( type => $type ) : (),
            );

            mount "/$url_base/_mapping" => sub {
                my $env = shift;
                my $req = _req($env);
                if ( $req->path_info ) {
                    return _not_found();
                }
                my $mapping = $self->es->indices->get_mapping(%args);

                if ( !%$mapping ) {
                    return _not_found();
                }
                return _json_response( 200, $mapping );
            };
            mount "/$url_base/_search" => sub {
                my $env = shift;
                my $req = _req($env);
                if ( $req->path_info ) {
                    return _not_found();
                }

                return $self->_search( \%args, $req );
            };
            mount "/$url_base" => sub {
                my $env = shift;
                my $req = _req($env);
                if ( my $path = $req->path_info ) {
                    my $item = $path =~ s{\A/}{}r;
                    if ( $item =~ m{/} ) {
                        return _not_found();
                    }

                    return $self->_get( \%args, $req, $item );
                }

                return $self->_all( \%args, $req );
            };
        }
        mount '/_search/scroll' => sub {
            my $env = shift;
            my $req = _req($env);

            my $scroll_id;
            my $scroll = $req->query_parameters->get('scroll');
            if ( my $path = $req->path_info ) {
                my $item = $path =~ s{\A/}{}r;
                if ( $item =~ m{/} ) {
                    return _not_found();
                }
                $scroll_id = $item;
            }
            elsif (my $qs_id = $res->query_parameters->get('scroll_id')) {
                $scroll_id = $qs_id;
            }
            elsif (my $body = $req->body_parameters) {
                $scroll_id = $body->get('scroll_id');
                $scroll = $body->get('scroll')
                    if $body->get('scroll');
            }

            my $res;
            if ($req->method eq 'DELETE') {
                $res = $self->es->clear_scroll(scroll_id => $scroll_id);
            }
            else {
                $res = $self->es->scroll(
                    scroll_id => $scroll_id,
                    defined $scroll ? (scroll => $scroll) : (),
                );
            }

            return _json_response(200, $res);
        };

        mount '/' => sub {
            return _not_found();
        };
    };
}

sub _req {
    my $env = shift;
    my $req = $env->{__PACKAGE__.'.request'};
    return $req
        if $req;
    $req = Plack::Request->new($env);
    $req->request_body_parser->register( 'application/json',
        'HTTP::Entity::Parser::JSON' );
    return $req;
}

sub _search {
    my ( $self, $args, $req ) = @_;

    $req->request_body_parser->register( 'application/json',
        'HTTP::Entity::Parser::JSON' );

    my @fields = map +( split /,/ ),
        $req->query_parameters->get_all('fields');

    my %params = %{ $req->query_parameters };

    if ( my $size = $params{size} ) {
        if ( $size > $MAX_SIZE ) {
            return _error( "size parameter exceeds maximum of $MAX_SIZE",
                416 );
        }
    }
    delete @params{qw(type index body join callback)};
    my $body
        = $req->content_length
        ? { %{ $req->body_parameters } }
        : delete $params{source};
    my $res;
    eval {
        $res = $self->es->search( {
            %$args,
            body => $body,
            %params,
            @fields ? ( fields => \@fields ) : (),
        } );
        1;
    } or do {
        return _error($@);
    };

    for my $hits ( @{ $res->{hits}{hits} } ) {
        if ( my $fields = $hits->{fields} ) {
            for my $field ( values %$fields ) {
                if ( is_arrayref($field) && @$field == 1 ) {
                    $field = $field->[0];
                }
            }
        }
    }

    return _json_response( 200, $res );
}

sub _all {
    my ( $self, $args, $req ) = @_;
    return $self->_search( $args, $req );
}

sub _get {
    my ( $self, $args, $req, $item ) = @_;
    my %args   = %$args;
    my @fields = map +( split /,/ ), $req->parameters->get_all('fields');
    my $doc    = $self->es->get(
        %args,
        @fields ? ( _source => \@fields ) : (),
        id => $item,
    );

    my $out = $doc->{_source};
    return _json_response( 200, $out );
}

sub _error {
    my ( $message, $error ) = @_;
    $error ||= 500;

    _json_response(
        $error,
        {
            "message" => "$message",
            "code"    => $error,
        }
    );

}

sub _not_found {
    _error( 'Not found', 404 );
}

sub _json_response {
    my ( $code, $content ) = @_;
    [
        $code,
        [ 'Content-Type' => 'application/json' ],
        [ encode_json($content) ]
    ];
}

1;
