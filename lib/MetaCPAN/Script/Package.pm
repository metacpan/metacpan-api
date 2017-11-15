package MetaCPAN::Script::Package;

use Moose;

use CPAN::DistnameInfo     ();
use IO::Uncompress::Gunzip ();
use Log::Contextual qw( :log );
use MetaCPAN::Document::Package ();
use MetaCPAN::Types qw( Bool );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Loads 02packages.details info into db.

=cut

has clean_up => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

sub run {
    my $self = shift;
    $self->index_packages;
    $self->index->refresh;
}

sub _get_02packages_fh {
    my $self = shift;
    my $file
        = $self->cpan->child(qw(modules 02packages.details.txt.gz))
        ->stringify;
    my $fh_uz = IO::Uncompress::Gunzip->new($file);
    return $fh_uz;
}

sub index_packages {
    my $self = shift;
    log_info {'Reading 02packages.details'};

    my $fh = $self->_get_02packages_fh;

    # read first 9 lines (meta info)
    my $meta = "Meta info:\n";
    for ( 0 .. 8 ) {
        chomp( my $line = <$fh> );
        next unless $line;
        $meta .= "$line\n";
    }
    log_debug {$meta};

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'package',
    );

    my %seen;
    log_debug {"adding data"};

    # read the rest of the file line-by-line (too big to slurp)
    while ( my $line = <$fh> ) {
        next unless $line;
        chomp($line);

        my ( $name, $version, $file ) = split /\s+/ => $line;
        my $distinfo = CPAN::DistnameInfo->new($file);

        my $doc = +{
            module_name  => $name,
            version      => $version,
            file         => $file,
            author       => $distinfo->cpanid,
            distribution => $distinfo->dist,
            dist_version => $distinfo->version,
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

    log_info {'finished indexing 02packages.details'};
}

sub run_cleanup {
    my ( $self, $bulk, $seen ) = @_;

    log_debug {"checking package data to remove"};

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'package',
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

Parse out CPAN package details (02packages.details).

    my $package = MetaCPAN::Script::Package->new;
    my $result  = $package->index_packages;

=head2 index_packages

Adds/updates all packages details in the CPAN index to Elasticsearch.

=cut
