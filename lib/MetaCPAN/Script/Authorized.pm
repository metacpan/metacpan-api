package MetaCPAN::Script::Authorized;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use List::MoreUtils qw(uniq);
use IO::Zlib ();

has dry_run => ( is => 'ro', isa => 'Bool', default => 0 );

sub run {
    my $self = shift;
    my $es   = $self->es;
    $self->index->refresh;
    log_info {"Dry run: updates will not be written to ES"}
    if ( $self->dry_run );
    my @authorized;
    my $authors = $self->parse_perms;
    log_info {"looking for modules"};
    my $scroll = $self->scroll;
    log_info { $scroll->total . " modules found" };
    my $update = 0;

    while ( my $file = $scroll->next ) {
        my $data = $file->{_source};
        my @modules = grep { $_->{indexed} } @{ $data->{module} };
        foreach my $module (@modules) {
            if ($data->{distribution} eq 'perl'
                || ( $authors->{ $module->{name} }
                    && grep { $_ eq $data->{author} }
                    @{ $authors->{ $module->{name} } } )
                )
            {
                $module->{authorized} = \1;
                $update = 1;
            }
            else {
                log_debug {
                    "unauthorized module $module->{name} in $data->{release} by $data->{author}";
                };
                $module->{authorized} = \0;
                $update = 1;
            }
        }
        if ( $authors->{ $data->{documentation} }
            && !grep { $_ eq $data->{author} }
            @{ $authors->{ $data->{documentation} } } )
        {
            log_debug {
                "unauthorized documentation $data->{documentation} in $data->{release} by $data->{author}";
            };
            $data->{authorized} = \0;
            $update = 1;
        }
        push( @authorized, $data ) if($update);
        if ( @authorized > 100 ) {
            $self->bulk_update(@authorized);
            @authorized = ();
        }
    }
    $self->bulk_update(@authorized) if (@authorized);    # update the rest
    $self->index->refresh;
}

sub bulk_update {
    my ( $self, @authorized ) = @_;
    if ( $self->dry_run ) {
        log_info {"dry run, not updating"};
        return;
    }
    my @bulk;
    foreach my $file (@authorized) {
        my ($module)
            = grep { $_->{name} eq $file->{documentation} }
            @{ $file->{module} }
            if ( $file->{documentation} );
        $file->{authorized} = $module->{authorized} if ($module);
        push(
            @bulk,
            {   index => {
                    index => $self->index->name,
                    type  => 'file',
                    id    => $file->{id},
                    data  => $file
                }
            }
        );
    }
    $self->es->bulk( \@bulk ) unless ( $self->dry_run );
}

sub scroll {
    my $self = shift;
    return $self->model->es->scrolled_search(
        {   index => $self->index->name,
            type  => 'file',
            query => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            { missing => { field => 'file.authorized' } },
                            {   or => [
                                    {   and => [
                                            {   exists => {
                                                    field =>
                                                        'file.module.name'
                                                }
                                            },
                                            {   term => {
                                                    'file.module.indexed' =>
                                                        \1
                                                }
                                            }
                                        ]
                                    },
                                    {   and => [
                                            {   exists => {
                                                    field => 'documentation'
                                                }
                                            },
                                            {   term =>
                                                    { 'file.indexed' => \1 }
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                }
            },
            scroll      => '1h',
            size        => 1000,
            search_type => 'scan',
        }
    );
}

sub parse_perms {
    my $self = shift;
    my $file = $self->cpan->file(qw(modules 06perms.txt.gz))->stringify;
    log_info {"parsing $file"};
    my $gz = IO::Zlib->new( $file, 'rb' );
    my %authors;
    while ( my $line = $gz->readline ) {
        my ( $module, $author, $type ) = split( /,/, $line );
        next unless ($type);
        $authors{$module} ||= [];
        push( @{ $authors{$module} }, $author );
    }
    return \%authors;

}

1;

__END__

=head1 NAME

MetaCPAN::Script::Authorized - set the C<authorized> property on files

=head1 DESCRIPTION

Unauthorized modules are modules that have been uploaded by by different
user than the previous version of the module unless the name of the
distribution matches.
