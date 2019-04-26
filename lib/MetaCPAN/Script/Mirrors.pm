package MetaCPAN::Script::Mirrors;

use strict;
use warnings;

use Cpanel::JSON::XS ();
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Document::Mirror;
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt', 'MetaCPAN::Role::ES';

sub run {
    my $self = shift;
    $self->index_mirrors;
    $self->refresh;
}

sub index_mirrors {
    my $self = shift;
    log_info { 'Getting mirrors.json file from ' . $self->cpan };

    my $json = $self->cpan->file( 'indices', 'mirrors.json' )->slurp;

    # Clear out everything in the index
    # so don't end up with old mirrors
    $self->delete_all_ids('mirror');

    my $mirrors = Cpanel::JSON::XS::decode_json($json);
    foreach my $mirror (@$mirrors) {
        $mirror->{location}
            = { lon => $mirror->{longitude}, lat => $mirror->{latitude} };
        Dlog_trace {"Indexing $_"} $mirror;

        $self->es->index(
            index => $self->index_name,
            type  => 'mirror',
            body  => {
                map { $_ => $mirror->{$_} }
                grep { defined $mirror->{$_} } keys %$mirror
            },
        );
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
