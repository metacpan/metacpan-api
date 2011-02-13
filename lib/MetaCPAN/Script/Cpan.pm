package MetaCPAN::Script::Cpan;

use Moose;
use File::Rsync::Mirror::Recent;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';

# $ENV{USER}           = "";    # fill in your name
# $ENV{RSYNC_PASSWORD} = "";    # fill in your passwd

sub run {
    my $self = shift;
    my @rrr = map {
        File::Rsync::Mirror::Recent->new(
            localroot => $self->cpan . "/$_",    # your local path
            remote => "ftp-stud.hs-esslingen.de::CPAN/$_/RECENT.recent",  # your upstream
            max_files_per_connection => 863,
            #tempdir =>
              #$self->cpan . "/_tmp",    # optional tempdir to hide temporary files
            ttl           => 10,
            rsync_options => {
                 #port             => 8732,    # only for PAUSE
                 compress         => 1,
                 links            => 1,
                 times            => 1,
                 checksum         => 0,
                 'omit-dir-times' => 1,       # not available before rsync 3.0.3
            },
            verbose    => 1,
            verboselog => "/tmp/rmirror-pause.log", )
    } "authors", "modules";
    die "directory $_ doesn't exist, giving up"
      for grep { !-d $_->localroot } @rrr;
    while () {
        my $ttgo = time + 1200; # or less
        for my $rrr (@rrr) {
            $rrr->rmirror( "skip-deletes" => 1 );
        }
        my $sleep = $ttgo - time;
        if ( $sleep >= 1 ) {
            print STDERR "sleeping $sleep ... ";
            sleep $sleep;
        }
    }
}
