package MetaCPAN::Script::Packages;

use Moose;

use Log::Contextual qw( :log );
use MetaCPAN::Document::Packages ();
use Parse::CPAN::Packages::Fast  ();
use IO::Uncompress::Gunzip       ();
use CPAN::DistnameInfo           ();

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Loads 02packages.details info into db.

=cut

sub run {
    my $self = shift;
    $self->index_packages;
    $self->index->refresh;
}

sub _get_02packages_fh {
    my $self = shift;
    my $file
        = $self->cpan->file(qw(modules 02packages.details.txt.gz))->stringify;
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

    my $bulk_helper = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'packages',
    );

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
        };

        $bulk_helper->update(
            {
                id            => $name,
                doc           => $doc,
                doc_as_upsert => 1,
            }
        );
    }

    $bulk_helper->flush;
    log_info {'finished indexing 02packages.details'};
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

Parse out CPAN packages details.

    my $packages = MetaCPAN::Script::Packages->new;
    my $result   = $packages->index_packages;

=head2 index_packages

Adds/updates all packages details in the CPAN index to Elasticsearch.

=cut
