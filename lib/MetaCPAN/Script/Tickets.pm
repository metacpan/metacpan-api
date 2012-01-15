package MetaCPAN::Script::Tickets;

use Moose;
use Log::Contextual qw( :log :dlog );
use List::AllUtils 'sum';
use LWP::UserAgent;
use Text::CSV;
use HTTP::Request::Common;
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
    my ($self, $summary) = @_;

    for my $dist (keys %{ $summary }) {
        my $dist_data =  $self->index->type('distribution')->inflate(0)->get({
            name => $dist,
        }) or next;

        use Data::Dump 'pp';
        pp $dist_data;

        $self->index->type('distribution')->put({
            %{ $dist_data->{_source} },
            rt_bug_count => $summary->{$dist},
        }, { refresh => 1 });
    }
}

sub retrieve_bug_summary {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new;
    my $resp = $ua->request(GET $self->rt_summary_url);

    confess $resp->reason unless $resp->is_success;

    return $self->parse_tsv($resp->content);
}

sub parse_tsv {
    my ($self, $tsv) = @_;
    $tsv =~ s/^#.*\n//mg;

    my $tsv_parser = Text::CSV->new({ sep_char => "\t" });
    open my $tsv_io, '<', \$tsv or confess $!;

    my %summary;
    while (my $row = $tsv_parser->getline($tsv_io)) {
        $summary{ $row->[0] } = sum @{ $row }[1..3];
    }

    return \%summary;
}

__PACKAGE__->meta->make_immutable;

1;
