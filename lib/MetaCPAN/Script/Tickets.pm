package MetaCPAN::Script::Tickets;

use Moose;
use Log::Contextual qw( :log :dlog );
use List::Util 'sum';
use LWP::UserAgent;
use Parse::CSV;
use HTTP::Request::Common;
use IO::String;
use namespace::autoclean;

with 'MooseX::Getopt', 'MetaCPAN::Role::Common';

has rt_summary_url => (
    is       => 'ro',
    required => 1,
    default  => 'https://rt.cpan.org/Public/bugs-per-dist.tsv',
);

sub run {
    my ($self) = @_;

    my $bug_summary = $self->retrieve_bug_summary;
    $self->index_bug_summary($bug_summary);

    return 1;
}

sub index_bug_summary {
    my ( $self, $summary ) = @_;

    my $bulk = $self->index->bulk( size => 300 );
    for my $dist ( keys %{$summary} ) {
        my $dist_data = $self->index->type('distribution')->raw->get($dist)
            or next;

        delete $dist_data->{exists};
        $bulk->put(
            {   %$dist_data,
                _source => {
                    %{ $dist_data->{_source} },
                    rt_bug_count => $summary->{$dist},
                }
            }
        );
    }
    $bulk->commit;
}

sub retrieve_bug_summary {
    my ($self) = @_;

    my $ua   = LWP::UserAgent->new;
    my $resp = $ua->request( GET $self->rt_summary_url );

    log_error { $resp->reason } unless $resp->is_success;

    return $self->parse_tsv( $resp->content );
}

sub parse_tsv {
    my ( $self, $tsv ) = @_;
    $tsv =~ s/^#.*\n//mg;

    my $tsv_parser = Parse::CSV->new(
        handle   => IO::String->new($tsv),
        sep_char => "\t"
    );

    my %summary;
    while ( my $row = $tsv_parser->fetch ) {
        $summary{ $row->[0] } = sum @{$row}[ 1 .. 3 ];
    }

    return \%summary;
}

__PACKAGE__->meta->make_immutable;

1;
