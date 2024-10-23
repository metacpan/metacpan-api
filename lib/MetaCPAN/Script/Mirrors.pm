package MetaCPAN::Script::Mirrors;

use strict;
use warnings;

use Cpanel::JSON::XS ();
use Log::Contextual  qw( :log :dlog );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;
    $self->index_mirrors;
    $self->es->indices->refresh;
}

sub index_mirrors {
    my $self = shift;
    log_info { 'Getting mirrors.json file from ' . $self->cpan };

    my $json = $self->cpan->child( 'indices', 'mirrors.json' )->slurp;
    my $type = $self->index->type('mirror');

    # Clear out everything in the index
    # so don't end up with old mirrors
    $type->delete;

    my $mirrors = Cpanel::JSON::XS::decode_json($json);
    foreach my $mirror (@$mirrors) {
        $mirror->{location}
            = { lon => $mirror->{longitude}, lat => $mirror->{latitude} };
        Dlog_trace {"Indexing $_"} $mirror;
        $type->put( {
            map  { $_ => $mirror->{$_} }
            grep { defined $mirror->{$_} } keys %$mirror
        } );
    }
    log_info {'done'};

    $self->cdn_purge_now( { keys => ['MIRRORS'], } );

}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan mirrors

=head1 SOURCE

L<http://www.cpan.org/indices/mirrors.json>

=cut
