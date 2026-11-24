package MetaCPAN::Script::BusFactor;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS   qw( decode_json );
use Log::Contextual    qw( :log :dlog );
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Types    qw( Int Uri );
use MetaCPAN::Util     qw( true false );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has bus_factor_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  =>
        'https://metacpan.github.io/metacpan-bus-factor/bus_factor.json.gz',
);

# Real feed is ~1.3MB gzipped: generous headroom that still bounds input size
has max_feed_size => (
    is      => 'ro',
    isa     => Int,
    default => 200 * 1024 * 1024,
);

sub run {
    my $self = shift;
    my $data = $self->retrieve_bus_factor_data;
    $self->index_bus_factor_data($data);

    return 1;
}

sub index_bus_factor_data {
    my ( $self, $data ) = @_;

    my $bulk = $self->es->bulk_helper( es_doc_path('distribution') );

    for my $dist ( sort keys %{$data} ) {
        $bulk->update( {
            id  => $dist,
            doc => {
                name  => $dist,
                river => { bus_factor => $data->{$dist}{bus_factor} },
            },
            doc_as_upsert => true,
        } );
    }
    $bulk->flush;
}

sub retrieve_bus_factor_data {
    my $self = shift;

    $self->ua->max_size( $self->max_feed_size );
    my $resp = $self->ua->get( $self->bus_factor_url );

    $self->handle_error( $resp->status_line, 1 ) unless $resp->is_success;

    # die_always: indexing a truncated body would be worse than stopping
    if ( my $aborted = $resp->header('Client-Aborted') ) {
        $self->handle_error(
            $aborted eq 'max_size'
            ? 'Bus factor feed is larger than '
                . $self->max_feed_size
                . ' bytes'
            : 'Bus factor feed download aborted: '
                . ( $resp->header('X-Died') // $aborted ),
            1
        );
    }

    # Fix up headers so that HTTP::Message::decoded_content knows to
    # decompress, since .json.gz is served as gzip type rather than
    # json encoded with gzip
    if ( ( $resp->header('Content-Type') // '' )
        =~ m{^application/(x-)?gzip$} )
    {
        $resp->header( 'Content-Type'     => 'application/json' );
        $resp->header( 'Content-Encoding' => 'gzip' );
    }

    # only gzip is expected; decoded_content does not cap e.g. deflate
    my $ce = $resp->header('Content-Encoding') // '';
    $self->handle_error(
        "Bus factor feed has unsupported Content-Encoding '$ce'", 1 )
        unless $ce =~ m{\A\s*(?:identity|none|x-gzip|gzip)?\s*\z}i;

    return decode_json( $resp->decoded_content(
        max_body_size => $self->max_feed_size,
        raise_error   => 1,
    ) );
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan bus_factor

=head1 DESCRIPTION

Retrieves the CPAN bus factor data from its source and
updates our ES information.

The bus factor for a distribution is taken from the feed's C<bus_factor>
field.

The feed is rejected if it, or its decompressed content, exceeds
C<--max_feed_size> bytes.

This can then be accessed here:

http://fastapi.metacpan.org/v1/distribution/Moose
http://fastapi.metacpan.org/v1/distribution/HTTP-BrowserDetect

=cut
