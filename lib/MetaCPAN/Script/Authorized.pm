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
    log_info { "Dry run: updates will not be written to ES" }
    if ( $self->dry_run );
    my @unauthorized;
    my ( $authors, $perl ) = $self->parse_perms;
    my $scroll = $self->scroll;
    log_info { $scroll->total . " modules found" };

    while ( my $file = $scroll->next ) {
        my $data = $file->{fields};
        next if ( $data->{distribution} eq 'perl' );
        my @modules =
          map  { $_->{name} }
          grep { $_->{indexed} } @{ $data->{'_source.module'} };
        foreach my $module (@modules) {
            next
              if ( $authors->{$module}
                && grep { $_ eq $data->{author} } @{ $authors->{$module} } );

            log_debug {
"unauthorized module $module in $data->{release} by $data->{author}";
            };
            push( @unauthorized, { file => $file->{_id}, module => $module } );
            if ( @unauthorized == 100 ) {
                $self->bulk_update(@unauthorized);
                @unauthorized = ();
            }

        }
    }
    $self->bulk_update(@unauthorized) if (@unauthorized);    # update the rest
}

sub bulk_update {
    my ( $self, @unauthorized ) = @_;
    if ( $self->dry_run ) {
        log_info { "dry run, not updating" };
        return;
    }
    my @bulk;
    my $es      = $self->model->es;
    my $results = $es->search(
        index => $self->index->name,
        type  => 'file',
        size  => scalar @unauthorized,
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    or => [
                        map { { term => { 'file.id' => $_->{file} } } }
                          @unauthorized
                    ]
                }
            }
        }
    );
    my %files =
      map { $_->{_source}->{id} => $_->{_source} }
      @{ $results->{hits}->{hits} };
    foreach my $item (@unauthorized) {
        my $file = $files{ $item->{file} };
        $file->{authorized} = \0
          if ( $file->{documentation}
            && $file->{documentation} eq $item->{module} );
        map { $_->{authorized} = \0 }
          grep { $_->{name} eq $item->{module} } @{ $file->{module} };
        push(
            @bulk,
            {
                create => {
                    index => $self->index->name,
                    type  => 'file',
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
        {
            index => $self->index->name,
            type  => 'file',
            query => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            {
                                not => {
                                    filter => {
                                        term =>
                                          { 'file.module.authorized' => \0 }
                                    }
                                }
                            },
                            { exists => { field => 'file.module.name' } }
                        ]
                    }
                }
            },
            scroll => '1h',
            size   => 1000,
            fields => [qw(distribution _source.module author release date)],
            sort   => ['date'],
        }
    );
}

sub parse_perms {
    my $self = shift;
    my $file = $self->cpan->file(qw(modules 06perms.txt.gz))->stringify;
    log_info { "parsing $file" };
    my $gz = IO::Zlib->new( $file, 'rb' );
    my ( %perl, %authors );
    while ( my $line = $gz->readline ) {
        my ( $module, $author, $type ) = split( /,/, $line );
        next unless ($type);
        $authors{$module} ||= [];
        if ( $author eq 'perl' ) {
            $perl{$module} = 1;
        }
        else {
            push( @{ $authors{$module} }, $author );
        }
    }
    return \%authors, \%perl;

}

1;

__END__

=head1 NAME

MetaCPAN::Script::Authorized - set the C<authorized> property on files

=head1 DESCRIPTION

Unauthorized modules are modules that have been uploaded by by different
user than the previous version of the module unless the name of the
distribution matches.
