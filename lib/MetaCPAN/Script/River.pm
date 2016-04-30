package MetaCPAN::Script::River;

use Moose;
use namespace::autoclean;

use JSON::MaybeXS qw( decode_json );
use Log::Contextual qw( :log :dlog );
use LWP::UserAgent;
use MetaCPAN::Types qw( ArrayRef Str Uri);

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has river_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  => 'https://neilb.org/FIXME',
);

has _ua => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new },
);

sub run {
    my $self      = shift;
    my $summaries = $self->retrieve_river_summaries;
    $self->index_river_summaries($summaries);

    return 1;
}

sub index_river_summaries {
    my ( $self, $summaries ) = @_;
    $self->index->refresh;
    my $dists = $self->index->type('distribution');
    my $bulk = $self->index->bulk( size => 300 );
    for my $summary (@$summaries) {
        my $dist = delete $summary->{dist};
        my $doc  = $dists->get($dist);
        $doc ||= $dists->new_document( { name => $dist } );
        $doc->_set_river($summary);
        $bulk->put($doc);
    }
    $bulk->commit;
}

sub retrieve_river_summaries {
    my $self = shift;
    my $resp = $self->_ua->get( $self->river_url );

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

http://api.metacpan.org/distribution/Moose
http://api.metacpan.org/distribution/HTTP-BrowserDetect

=cut

