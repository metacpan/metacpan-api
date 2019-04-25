package MetaCPAN::Script::Cover;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS qw( decode_json );
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Types qw( Bool Uri);

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has cover_url => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    default => 'http://cpancover.com/latest/cpancover.json',
);

has cover_dev_url => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    default => 'http://cpancover.com/latest/cpancover_dev.json',
);

has test => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Test mode (pulls smaller development data set)',
);

my %valid_keys
    = map { $_ => 1 } qw< branch condition statement subroutine total >;

sub run {
    my $self = shift;
    my $data = $self->retrieve_cover_data;
    $self->index_cover_data($data);
    return 1;
}

sub index_cover_data {
    my ( $self, $data ) = @_;

    my $bulk = $self->es->bulk_helper(
        index => 'cover',
        type  => 'cover',
    );

    log_info {'Updating the cover index'};

    for my $dist ( sort keys %{$data} ) {
        for my $version ( keys %{ $data->{$dist} } ) {
            my $release   = $dist . '-' . $version;
            my $rel_check = $self->es->search(
                index => 'cpan',
                type  => 'release',
                size  => 0,
                body  => {
                    query => { term => { name => $release } },
                },
            );
            if ( $rel_check->{hits}{total} ) {
                log_info { "Adding release info for '" . $release . "'" };
            }
            else {
                log_warn { "Release '" . $release . "' does not exist." };
                next;
            }

            my %doc_data = %{ $data->{$dist}{$version}{coverage}{total} };

            for my $k ( keys %doc_data ) {
                delete $doc_data{$k} unless exists $valid_keys{$k};
            }

            $bulk->update(
                {
                    id  => $release,
                    doc => {
                        distribution => $dist,
                        version      => $version,
                        release      => $release,
                        criteria     => \%doc_data,
                    },
                    doc_as_upsert => 1,
                }
            );
        }
    }

    $bulk->flush;
}

sub retrieve_cover_data {
    my $self = shift;

    my $url = $self->test ? $self->cover_dev_url : $self->cover_url;

    log_info { 'Fetching data from ', $url };
    my $resp = $self->ua->get($url);

    $self->handle_error( $resp->status_line ) unless $resp->is_success;

    # clean up headers if .json.gz is served as gzip type
    # rather than json encoded with gzip
    if ( $resp->header('Content-Type') eq 'application/x-gzip' ) {
        $resp->header( 'Content-Type'     => 'application/json' );
        $resp->header( 'Content-Encoding' => 'gzip' );
    }

    return decode_json( $resp->decoded_content );
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan cover [--test]

=head1 DESCRIPTION

Retrieves the CPAN cover data from its source and
updates our ES information.

=cut
