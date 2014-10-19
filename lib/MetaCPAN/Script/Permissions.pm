package MetaCPAN::Script::Permissions;

use strict;
use warnings;

use Moose;
with 'MooseX::Getopt', 'MetaCPAN::Role::Common';

use Log::Contextual qw( :log );
use PAUSE::Permissions;

use MetaCPAN::Document::Permissions;

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
    my $type      = $self->index->type('permissions');
    my $bulk      = $self->model->bulk( size => 100 );

    my $iterator = $pp->module_iterator();
    while ( my $mp = $iterator->next_module ) {
        my $put = { name => $mp->name };
        $put->{owner}          = $mp->owner          if $mp->owner;
        $put->{co_maintainers} = $mp->co_maintainers if $mp->co_maintainers;
        $bulk->put( $type->new_document($put) );
    }

    $self->index->refresh;
    log_info {'done'};
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

Parse out CPAN author permissions.

    my $perms = MetaCPAN::Script::Permissions->new;
    my $result = $perms->index_permissions;

=head2 index_authors

Adds/updates all ownership and maintenance permissions in the CPAN index to
ElasticSearch.

=cut
