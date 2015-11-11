package MetaCPAN::Script::Mirrors;

use strict;
use warnings;

use JSON ();
use LWP::UserAgent;
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Document::Mirror;
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;
    $self->index_mirrors;
    $self->index->refresh;
}

sub index_mirrors {
    my $self = shift;
    my $ua   = LWP::UserAgent->new;
    log_info { 'Getting mirrors.json file from ' . $self->cpan };

    my $json    = $self->cpan->file( 'indices', 'mirrors.json' )->slurp;
    my $type    = $self->index->type('mirror');
    my $mirrors = JSON::XS::decode_json($json);
    foreach my $mirror (@$mirrors) {
        $mirror->{location}
            = { lon => $mirror->{longitude}, lat => $mirror->{latitude} };
        Dlog_trace {"Indexing $_"} $mirror;
        $type->put(
            {
                map { $_ => $mirror->{$_} }
                grep { defined $mirror->{$_} } keys %$mirror
            }
        );
    }
    log_info {'done'};
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan mirrors

=head1 SOURCE

L<http://www.cpan.org/indices/mirrors.json>

=cut
