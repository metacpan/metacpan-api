package MetaCPAN::Script::Tickets;

use Moose;
use Log::Contextual qw( :log :dlog );
use List::MoreUtils qw(uniq);
use List::Util      qw(sum);
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

has source => (
    is       => 'ro',
    required => 1,
    isa      => 'ArrayRef[Str]',
    default  => sub { [qw(rt)] },
);

has ua => (
    is      => 'ro',
    default => sub { LWP::UserAgent->new },
);

sub run {
    my ($self) = @_;
    my $bugs = {};
    foreach my $source ( @{ $self->source } ) {
        if ( $source eq 'rt' ) {
            $bugs->{$source} = $self->retrieve_rt_bugs;
        }
    }
    $self->index_bug_summary($bugs);

    return 1;
}

sub index_bug_summary {
    my ( $self, $summary ) = @_;

    my $bulk = $self->index->bulk( size => 300 );
    for my $dist ( uniq map { keys %$_ } values %{$summary} ) {
        my $dist = $self->index->type('distribution')->get($dist)
            or next;
        $dist->add_bugs(
            grep {defined}
            map  { $summary->{$_}->{ $dist->name } } keys %$summary
        );
        $bulk->put($dist);
    }
    $bulk->commit;
}

sub retrieve_rt_bugs {
    my ($self) = @_;

    my $resp = $self->ua->request( GET $self->rt_summary_url );

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
            map { $_ => $row->[ $i++ ] + 0 }
                qw(new open stalled resolved rejected),
        };
    }

    return \%summary;
}

__PACKAGE__->meta->make_immutable;

1;
