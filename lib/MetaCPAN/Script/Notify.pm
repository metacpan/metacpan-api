package MetaCPAN::Script::Notify;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';

use Filesys::Notify::Simple;

sub run {
    my $self = shift;
    my $watcher = Filesys::Notify::Simple->new( [ $self->cpan ] );
    $watcher->wait( \&process_events ) while (1);
}

sub process_events {
    for my $event (@_) {
        my $path = $event->{path};

        # only get the good stuff
        next
          unless ( $path =~ /\/authors\/id\/\w\/\w\w\/\w+\/[^\/]+\.tar\.gz$/ );
        warn $path;
    }
}
