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
    my $pp        = PAUSE::Permissions->new( path => $file_path );
    my $type      = $self->index->type('permission');
    my $bulk      = $self->model->bulk( size => 100 );

    my $iterator = $pp->module_iterator;
    while ( my $perms = $iterator->next_module ) {
        my $put = { module => $perms->name };
        $put->{owner} = $perms->owner if $perms->owner;
        $put->{co_maintainers} = $perms->co_maintainers
            if $perms->co_maintainers;
        $bulk->put( $type->new_document($put) );
    }

    $bulk->commit;

    $self->index->refresh;
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
