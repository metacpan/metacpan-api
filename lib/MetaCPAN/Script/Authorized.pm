package MetaCPAN::Script::Authorized;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use List::MoreUtils qw(uniq);

has dry_run => ( is => 'ro', isa => 'Bool', default => 0 );

sub run {
    my $self = shift;
    log_info {"Dry run: updates will not be written to ES"}
    if ( $self->dry_run );
    my @authorized;
    my $authors = $self->parse_perms;
    log_info {"looking for modules"};
    my $scroll = $self->scroll;
    log_info { $scroll->total . " modules found" };
    my $update = 0;
    my @releases;

    while ( my $file = $scroll->next ) {
        my $data = $file->{_source};
        next if ( $data->{distribution} eq 'perl' );
        my @modules
            = grep { $_->{indexed} && $_->{authorized} } @{ $data->{module} };
        foreach my $module (@modules) {
            if (!$authors->{ $module->{name} }
                || !(
                    $authors->{ $module->{name} }
                    && grep { $_ eq $data->{author} }
                    @{ $authors->{ $module->{name} } }
                )
                )
            {
                log_debug {
                    "unauthorized module $module->{name} in $data->{release} by $data->{author}";
                };
                $module->{authorized} = \0;
                $update = 1;
            }
        }
        if (   !defined $data->{authorized}
            && $data->{documentation}
            && $authors->{ $data->{documentation} }
            && !grep { $_ eq $data->{author} }
            @{ $authors->{ $data->{documentation} } } )
        {
            log_debug {
                "unauthorized documentation $data->{documentation} in $data->{release} by $data->{author}";
            };
            $data->{authorized} = \0;
            $update = 1;
        }
        push( @authorized, $data ) if ($update);
        if ( @authorized > 100 ) {
            $self->bulk_update(@authorized);
            @authorized = ();
        }
    }
    $self->bulk_update(@authorized)
        if (@authorized);    # update the rest
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
        $file->{authorized} = $module->{authorized}
            if ( $module && $module->{indexed} );
        push(
            @bulk,
            {   index => {
                    index  => $self->index->name,
                    type   => 'file',
                    id     => $file->{id},
                    parent => $file->{release_id},
                    data   => $file
                }
            }
        );
    }
    $self->es->bulk( \@bulk ) unless ( $self->dry_run );
}

sub scroll {
    my $self = shift;
    $self->index->refresh;
    return $self->model->es->scrolled_search(
        {   index => $self->index->name,
            type  => 'file',
            query => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        or => [
                            { exists => { field => 'file.module.name' } },

                            { exists => { field => 'documentation' } }
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
    my $file = $self->cpan->file(qw(modules 06perms.txt));
    log_info {"parsing ", $file};
    my $fh = $file->openr;
    my %authors;
    while ( my $line = <$fh> ) {
        my ( $module, $author, $type ) = split( /,/, $line );
        next unless ($type);
        $authors{$module} ||= [];
        push( @{ $authors{$module} }, $author );
    }
    die;
    return \%authors;

}

1;

__END__

=head1 NAME

MetaCPAN::Script::Authorized - Set the C<authorized> property on files

=head1 SYNOPSIS

 $ bin/metacpan authorized
 
 $ bin/metacpan release /path/to/tarball.tar.gz --authorized

=head1 DESCRIPTION

Unauthorized modules are modules that were uploaded in the name of a
different author than stated in the C<06perms.txt.gz> file. One problem
with this file is, that it doesn't record historical data. It may very
well be that an author was authorized to upload a module at the time.
But then his co-maintainer rights might have been revoked, making consecutive
uploads of that release unauthorized. However, since this script runs
with the latest version of C<06perms.txt.gz>, the former upload will
be flagged as unauthorized as well. Same holds the other way round,
a previously unauthorized release would be flagged authorized if the
co-maintainership was added later on.

If a release contains unauthorized modules, the whole release is marked
as unauthorized as well.
