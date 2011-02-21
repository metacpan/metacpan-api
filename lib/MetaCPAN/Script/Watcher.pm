package MetaCPAN::Script::Watcher;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';

use feature qw(say);
use AnyEvent::FriendFeed::Realtime;
use AnyEvent::Run;

my $fails = 0;
sub run {
    my $self = shift;
    say "Reconnecting after $fails fails" if($fails);
    my($user, $remote_key, $request) = @ARGV;
    my $done = AnyEvent->condvar;

    binmode STDOUT, ":utf8";
    my %handles;
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request    => "/feed/cpan",
        on_entry   => sub {
            my $entry = shift;
            $entry->{body} =~ /href="(.*?)"/;
            my $file = $1;
            return unless( $file );
            $handles{$file} = AnyEvent::Run->new(
                class => 'MetaCPAN::Script::Release',
                args => ['--latest', $file],
                on_read => sub { },
                on_eof => sub { },
                on_error  => sub {
                    my ($handle, $fatal, $msg) = @_;
                    my $arg = $handle->{args}->[0];
                    say "Indexing $arg done";
                    say $handle->rbuf;
                }
            );
        },
        on_error   => sub {
            $done->send;
        },
    );
    say "Up and running. Watching for updates on http://friendfeed.com/cpan ..."
        unless($fails);
    $done->recv;
    $fails++;
    $self->run if($fails < 5);
    say "Giving up after $fails fails";
    
}

1;