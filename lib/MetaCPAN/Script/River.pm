package MetaCPAN::Script::River;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS          qw( decode_json );
use Log::Contextual           qw( :log :dlog );
use MetaCPAN::Types::TypeTiny qw( Uri );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has river_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  => 'http://neilb.org/river-of-cpan.json.gz',
);

sub run {
    my $self      = shift;
    my $summaries = $self->retrieve_river_summaries;
    $self->index_river_summaries($summaries);

    return 1;
}

sub index_river_summaries {
    my ( $self, $summaries ) = @_;

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'distribution',
    );

    for my $summary ( @{$summaries} ) {
        my $dist = delete $summary->{dist};

        $bulk->update( {
            id  => $dist,
            doc => {
                name  => $dist,
                river => $summary,
            },
            doc_as_upsert => 1,
        } );
    }
    $bulk->flush;
}

sub retrieve_river_summaries {
    my $self = shift;

    my $resp = $self->ua->get( $self->river_url );

    $self->handle_error( $resp->status_line ) unless $resp->is_success;

    # cleanup headers if .json.gz is served as gzip type
    # rather than json encoded with gzip
    if ( $resp->header('Content-Type') eq 'application/x-gzip' ) {
        $resp->header( 'Content-Type'     => 'application/json' );
        $resp->header( 'Content-Encoding' => 'gzip' );
    }

    return decode_json $resp->decoded_content;
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan river

=head1 DESCRIPTION

Retrieves the CPAN river data from its source and
updates our ES information.

This can then be accessed here:

http://fastapi.metacpan.org/v1/distribution/Moose
http://fastapi.metacpan.org/v1/distribution/HTTP-BrowserDetect

=cut

