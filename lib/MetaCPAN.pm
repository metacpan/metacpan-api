package MetaCPAN;

use Modern::Perl;
use Moose;
use Archive::Tar;
use CPAN::DistnameInfo;
use ElasticSearch;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);

has 'es' => ( is => 'rw', lazy_build => 1 );

has 'cpan' => (
    is         => 'rw',
    isa        => 'Str',
);

has 'pkg_index' => (
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_es {

    my $e = ElasticSearch->new(
        servers     => 'localhost:9200',
        transport   => 'httplite',             # default 'http'
        trace_calls => 'log_file',
    );

}

sub open_pkg_index {

    my $self = shift;
    my $file = $self->cpan . '/modules/02packages.details.txt.gz';
    my $tar  = Archive::Tar->new;

    my $z = new IO::Uncompress::AnyInflate $file
        or die "anyinflate failed: $AnyInflateError\n";

    return $z;

}

sub _build_pkg_index {

    my $self  = shift;
    my $file  = $self->open_pkg_index;
    my %index = ();

    my $skip = 1;

LINE:
    while ( my $line = $file->getline ) {
        if ( $skip ) {
            $skip = 0 if $line eq "\n";
            next LINE;
        }

        my ( $module, $version, $archive ) = split m{\s{1,}}xms, $line;

        # DistNameInfo converts 1.006001 to 1.6.1
        my $d = CPAN::DistnameInfo->new( $archive );

        $index{$module} = {
            archive   => $d->pathname,
            version   => $d->version,
            author    => $d->cpanid,
            dist      => $d->dist,
            distvname => $d->distvname,
        };
    }

    return \%index;

}

1;
