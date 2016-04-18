package MetaCPAN::Script::Query;

use strict;
use warnings;

use Data::DPath qw(dpath);
use JSON::XS;
use Moose;
use MooseX::Aliases;
use YAML::Syck qw(Dump);
use MetaCPAN::Types qw( Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

$YAML::Syck::SortKeys = $YAML::Syck::Headless = $YAML::Syck::ImplicitTyping
    = $YAML::Syck::UseCode = 1;

has X => (
    is            => 'ro',
    default       => 'GET',
    documentation => 'request method',
);

has d => (
    is            => 'ro',
    isa           => Str,
    documentation => 'request body',
);

sub run {
    my $self = shift;
    my ( undef, $cmd, $path ) = @{ $self->extra_argv };
    $path ||= '/';
    my $es   = $self->es;
    my $json = $es->transport->send_request(
        $self->remote,
        {
            method => $self->X,
            cmd    => $cmd,
            $self->d ? ( data => $self->d ) : ()
        }
    );
    my @results = dpath($path)->match( decode_json($json) );
    ( my $dump = Dump(@results) ) =~ s/\!\!perl\/scalar:JSON::XS::Boolean //g;
    print $dump;

}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan query /_status //store_size
 # bin/metacpan query /cpan/module/_search \
    -d '{"query":{"wildcard":{"name":"Path*"}}}' /hits/total
 # bin/metacpan query /cpan/author/_search \
    -d '{"query":{"field":{"cats":"*"}}}' //cats

 # You guys should seriously clean up your directory:
 # bin/metacpan query /cpan/release/_search \
    -d '{"query":{"match_all":{}},"facets":{"stat1":{"terms":{"script_field":"_source.author + \"/\" + _source.distribution"}}}}}' //terms

=head1 DESCRIPTION

Issues a query to the ElasticSearch server, parses the response
and uses L<Data::DPath> to select parts of the response.
