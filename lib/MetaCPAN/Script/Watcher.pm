package MetaCPAN::Script::Watcher;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Log::Contextual qw( :log );

use feature qw(say);
use AnyEvent::FriendFeed::Realtime;
use AnyEvent::Run;

my $fails = 0;
sub run {
    my $self = shift;
    log_warn { "Reconnecting after $fails fails" } if($fails);
    my($user, $remote_key, $request) = @ARGV;
    my $done = AnyEvent->condvar;

    binmode STDOUT, ":utf8";
    my %handles;

    my $client = AnyEvent::FriendFeed::Realtime->new(
        request    => "/feed/cpan",
        on_entry   => sub {
            my $entry = shift;
            $fails = 0; # on_connect actually
            $entry->{body} =~ /href="(.*?)"/;
            my $file = $1;
            return unless( $file );
            $handles{$file} = AnyEvent::Run->new(
                class => 'MetaCPAN::Script::Runner',
                args => ['release', $file, '--latest', '--level', $self->level],
                on_read => sub { },
                on_eof => sub { },
                on_error  => sub {
                    my ($handle, $fatal, $msg) = @_;
                    my $arg = $handle->{args}->[1];
                    log_info { "New upload: $arg" };
                    say $handle->rbuf;
                }
            );
        },
        on_error   => sub {
            $done->send;
        },
    );
    log_info { "Up and running. Watching http://friendfeed.com/cpan for updates" }
        unless($fails);
    $done->recv;
    $fails++;
    $self->run if($fails < 5);
    log_fatal { "Giving up after $fails fails" };
    
}

1;

=head1 SYNOPSIS

 # bin/metacpan watcher

=head1 DESCRIPTION

Uses L<AnyEvent::FriendFeed::Realtime> to watch the CPAN friendfeed.
On a new upload it will fork a new process using L<AnyEvent::Run>
and run L<MetaCPAN::Script::Release> to index the new release.

If the connection to friendfeed is reset the process will try up
to five times to reconnects or exists otherwise.

=head1 SOURCE

L<http://friendfeed.com/cpan>