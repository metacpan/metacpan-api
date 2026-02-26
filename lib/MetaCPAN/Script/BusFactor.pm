package MetaCPAN::Script::BusFactor;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS          qw( decode_json );
use Log::Contextual           qw( :log :dlog );
use MetaCPAN::ESConfig        qw( es_doc_path );
use MetaCPAN::Types::TypeTiny qw( Uri );
use MetaCPAN::Util            qw( true false );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has bus_factor_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  =>
        'https://metacpan.github.io/metacpan-bus-factor/bus_factor.json.gz',
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
        my $entry      = $data->{$dist};
        my $bus_factor = scalar @{ $entry->{active_maintainers} || [] };

        $bulk->update( {
            id  => $dist,
            doc => {
                name  => $dist,
                river => { bus_factor => $bus_factor },
            },
            doc_as_upsert => true,
        } );
    }
    $bulk->flush;
}

sub retrieve_bus_factor_data {
    my $self = shift;

    my $resp = $self->ua->get( $self->bus_factor_url );

    $self->handle_error( $resp->status_line ) unless $resp->is_success;
    return decode_json $resp->decoded_content;
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan bus_factor

=head1 DESCRIPTION

Retrieves the CPAN bus factor data from its source and
updates our ES information.

The bus factor for a distribution is the number of active maintainers.

This can then be accessed here:

http://fastapi.metacpan.org/v1/distribution/Moose
http://fastapi.metacpan.org/v1/distribution/HTTP-BrowserDetect

=cut
