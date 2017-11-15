package MetaCPAN::Script::Permission;

use Moose;

use Log::Contextual qw( :log );
use MetaCPAN::Document::Permission ();
use MetaCPAN::Types qw( Bool );
use PAUSE::Permissions ();

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Loads 06perms info into db. Does not require the presence of a local
CPAN/minicpan.

=cut

has clean_up => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

sub run {
    my $self = shift;
    $self->index_permissions;
    $self->index->refresh;
}

sub index_permissions {
    my $self = shift;

    my $file_path = $self->cpan->child( 'modules', '06perms.txt' )->absolute;
    my $pp = PAUSE::Permissions->new( path => $file_path );

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'permission',
    );

    my %seen;
    log_debug {"building permission data to add"};

    my $iterator = $pp->module_iterator;
    while ( my $perms = $iterator->next_module ) {

        # This method does a "return sort @foo", so it can't be called in the
        # ternary since it always returns false in that context.
        # https://github.com/neilb/PAUSE-Permissions/pull/16

        my $name = $perms->name;

        my @co_maints = $perms->co_maintainers;
        my $doc       = {
            module_name => $name,
            owner       => $perms->owner,

            # empty list means no co-maintainers
            # and passing the empty arrayref will force
            # deleting existingd values in the field.
            co_maintainers => \@co_maints,
        };

        $bulk->update(
            {
                id            => $name,
                doc           => $doc,
                doc_as_upsert => 1,
            }
        );

        $seen{$name} = 1;
    }
    $bulk->flush;

    $self->run_cleanup( $bulk, \%seen ) if $self->clean_up;

    log_info {'finished indexing 06perms'};
}

sub run_cleanup {
    my ( $self, $bulk, $seen ) = @_;

    log_debug {"checking permission data to remove"};

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'permission',
        scroll => '30m',
        body   => { query => { match_all => {} } },
    );

    my @remove;
    my $count = $scroll->total;
    while ( my $p = $scroll->next ) {
        my $id = $p->{_id};
        unless ( exists $seen->{$id} ) {
            push @remove, $id;
            log_debug {"removed $id"};
        }
        log_debug { $count . " left to check" } if --$count % 10000 == 0;
    }
    $bulk->delete_ids(@remove);
    $bulk->flush;
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

Parse out CPAN author permissions.

    my $perms = MetaCPAN::Script::Permission->new;
    my $result = $perms->index_permissions;

=head2 index_authors

Adds/updates all ownership and maintenance permissions in the CPAN index to
Elasticsearch.

=cut
