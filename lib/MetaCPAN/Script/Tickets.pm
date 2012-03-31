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
        my $dist = $self->index->type('distribution')->get($dist)
            or next;
        $dist->add_bugs( $summary->{ $dist->name } );
        $bulk->put($dist);
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
        my $i = 1;
        $summary{ $row->[0] } = {
            source => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=' . $row->[0],
            active => ( sum @{$row}[ 1 .. 3 ] ),
            closed => ( sum @{$row}[ 4 .. 5 ] ),
            map { $_ => $row->[ $i++ ]+0 }
                qw(new open stalled resolved rejected),
        };
    }

    return \%summary;
}

__PACKAGE__->meta->make_immutable;

1;
