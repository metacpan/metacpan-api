package MetaCPAN::Script::Mirrors;

use Moose;
use feature 'say';
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use LWP::UserAgent;
use MetaCPAN::Document::Mirror;
use JSON::XS ();

sub run {
    my $self = shift;
    $self->index_mirrors;
    $self->es->refresh_index( index => 'cpan' );
}

sub index_mirrors {
    my $self      = shift;
    my $ua = LWP::UserAgent->new;
    log_info { "Downloading mirrors file" };
    my $res = $ua->get("http://www.cpan.org/indices/mirrors.json");
    unless($res->is_success) {
        log_fatal { "Could not get mirrors file" };
        exit;
    }
    my $type = $self->model->index('cpan')->type('mirror');
    my $mirrors = JSON::XS::decode_json($res->content);
    foreach my $mirror(@$mirrors) {
        $mirror->{location} = { lon => $mirror->{longitude}, lat => $mirror->{latitude} };
        Dlog_trace { "Indexing $_" } $mirror;
        $type->put({ map { $_ => $mirror->{$_} } grep { defined $mirror->{$_} } keys %$mirror });
    }
    log_info { "done" };
}


1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan mirrors

=head1 SOURCE

L<http://www.cpan.org/indices/mirrors.json>

=cut
