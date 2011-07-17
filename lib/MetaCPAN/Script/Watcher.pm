package MetaCPAN::Script::Watcher;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Log::Contextual qw( :log );

use JSON::XS;

has backpan => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'update deleted tarballs only',
);
has dry_run => ( is => 'ro', isa => 'Bool', default => 0 );

my $fails    = 0;
my $latest   = 0;
my @segments = qw(1h 6h 1d 1W 1M 1Q 1Y Z);

sub run {
    my $self = shift;
    while (1) {
        $latest = $self->latest_release;
        my @changes = $self->changes;
        while ( my $release = pop(@changes) ) {
            $self->index_release($release);
        }
        sleep(15);
    }
}

sub changes {
    my $self = shift;
    my $now  = DateTime->now->epoch;
    my $archive = $latest->archive unless($self->backpan);
    my %seen;
    my @changes;
    for my $segment (@segments) {
        log_debug {"Loading RECENT-$segment.json"};
        my $json
            = decode_json( $self->cpan->file("RECENT-$segment.json")->slurp );
        for (
            grep {
                    $_->{path}
                    =~ /^authors\/id\/.*\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/
            } grep { $self->backpan ? $_->{type} eq "delete" : 1 }
            @{ $json->{recent} }
            )
        {
            my $seen = $seen{ $_->{path} };
            next
                if ( $seen
                && ( $_->{type} eq $seen->{type} || $_->{type} eq 'delete' )
                );
            $seen{ $_->{path} } = $_;
	    if($self->backpan) {
	       if($self->skip($_->{path})) {
	       log_info {"Skipping $_->{path}"};
	       next;
	       }
	    } elsif($_->{path} =~ /\/\Q$archive\E$/) {
	       last;
	    }
            push( @changes, $_ );
        }
        if ( !$self->backpan && $json->{meta}->{minmax}->{min} < $latest->date->epoch ) {
            log_debug {"Includes latest release"};
            last;
        }
    }
    return @changes;
}

sub latest_release {
    my $self   = shift;
    return undef if($self->backpan);
    return $self->index->type('release')->query(
        {   query => { match_all => {} },
            $self->backpan
            ? ( filter => { term => { 'release.status' => 'backpan' } } )
            : (),
            sort  => [ { 'date' => { order => "desc" } } ]
        }
    )->first;
}

sub skip {
    my ($self, $archive) = @_;
    $archive =~ s/^.*\///;
    return $self->index->type('release')->query(
                {   query => {
                        filtered => {
                            query  => { match_all => {} },
                            filter => {
                                and => [
				    { term => { status => 'backpan' } },
                                    { term => { archive => $archive } },
                                    #{ term => { author  => $author } },
                                ]
                            }
                        }
                    }
                }
            )->inflate(0)->count;
}

sub index_release {
    my ( $self, $release ) = @_;
    my $tarball = $self->cpan->file( $release->{path} )->stringify;
    for ( my $i = 0; $i < 15; $i++ ) {
        last if ( -e $tarball );
        log_warn {"Tarball $tarball does not yet exist"};
        sleep(1);
    }

    unless ( -e $tarball ) {
        log_error {
            "Aborting, tarball $tarball not available after 15 seconds";
        };
        return;
    }

    my @run = (
        $FindBin::RealBin . "/metacpan",
        'release',
        $tarball,
        $release->{type} eq 'new' ? '--latest' : ( '--status', 'backpan' ),
        '--index',
        $self->index->name
    );
    log_debug {"Running @run"};
    system(@run) unless ( $self->dry_run );
}

1;

=head1 SYNOPSIS

 # bin/metacpan watcher

=head1 DESCRIPTION

This script requires a local CPAN mirror. It watches the RECENT-*.json
files for changes to the CPAN directory every 15 seconds. New uploads
as well as deletions are processed sequentially.

=head1 OPTIONS

=head2 --backpan

This will look for the most recent release that has been deleted.
From that point on, it will look in the RECENT files for new deletions
and process them.

L<http://friendfeed.com/cpan>
