package MetaCPAN::Script::Permission;

use MetaCPAN::Moose;

use Log::Contextual qw( :log );
use MetaCPAN::Document::Permission ();
use PAUSE::Permissions             ();

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Loads 06perms info into db. Does not require the presence of a local
CPAN/minicpan.

=cut

sub run {
    my $self = shift;
    $self->index_permissions;
    $self->index->refresh;
}

sub index_permissions {
    my $self = shift;

    my $file_path = $self->cpan . '/modules/06perms.txt';
    my $pp = PAUSE::Permissions->new( path => $file_path );

    my $bulk_helper = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'permission',
    );

    my $iterator = $pp->module_iterator;
    while ( my $perms = $iterator->next_module ) {
        $bulk_helper->update(
            {
                id  => $perms->name,
                doc => {
                    $perms->co_maintainers
                    ? ( co_maintainers => $perms->co_maintainers )
                    : (),
                    module_name => $perms->name,
                    owner       => $perms->owner,
                },
                doc_as_upsert => 1,
            }
        );
    }

    $bulk_helper->flush;
    log_info {'finished indexing 06perms'};
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
