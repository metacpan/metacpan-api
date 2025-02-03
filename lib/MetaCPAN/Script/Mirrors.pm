package MetaCPAN::Script::Mirrors;

use strict;
use warnings;

use Cpanel::JSON::XS ();
use Log::Contextual  qw( :log :dlog );
use Moose;
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( true false );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;
    $self->index_mirrors;
    $self->es->indices->refresh;
}

sub index_mirrors {
    my $self = shift;
    log_info { 'Getting mirrors.json file from ' . $self->cpan };

    my $es = $self->es;

    my $json    = $self->cpan->child( 'indices', 'mirrors.json' )->slurp;
    my $mirrors = Cpanel::JSON::XS::decode_json($json);
    my %mirrors = map +( $_->{name} => $_ ), @$mirrors;

    my $need_purge;

    my $scroll = $es->scroll_helper( es_doc_path('mirror'), size => 500, );
    my $bulk   = $es->bulk_helper(
        es_doc_path('mirror'),
        on_success => sub {
            my ( $method, $res ) = @_;
            if ( $method eq 'update' ) {

                # result is not supported until 5, but this will work when we
                # update
                if ( exists $res->{result} ) {
                    return
                        if $res->{result} eq 'noop';
                }
            }
            $need_purge++;
        },
    );
    while ( my $doc = $scroll->next ) {
        if ( !$mirrors{ $doc->{_id} } ) {
            Dlog_trace {"Deleting $doc->{_id}"};
            $bulk->delete_ids( $doc->{_id} );
        }
    }

    for my $mirror (@$mirrors) {
        my $data = {%$mirror};
        delete $data->{$_} for grep !defined $data->{$_}, keys %$data;
        $data->{location} = {
            lon => delete $mirror->{longitude},
            lat => delete $mirror->{latitude},
        };

        Dlog_trace {"Indexing $_"} $mirror;
        $bulk->update( {
            id            => $mirror->{name},
            doc           => $data,
            doc_as_upsert => true,
        } );
    }

    $bulk->flush;

    log_info {'done'};

    $self->cdn_purge_now( { keys => ['MIRRORS'] } )
        if $need_purge;

}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan mirrors

=head1 SOURCE

L<http://www.cpan.org/indices/mirrors.json>

=cut
