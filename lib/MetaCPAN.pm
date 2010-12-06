package MetaCPAN;

use Modern::Perl;
use Moose;

with 'MetaCPAN::Role::Common';
with 'MetaCPAN::Role::DB';

use Archive::Tar;
use CPAN::DistnameInfo;
use Data::Dump qw( dump );
use DateTime::Format::Epoch::Unix;
use ElasticSearch;
use Every;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);

use MetaCPAN::Dist;
use MetaCPAN::Schema;

has 'cpan' => (
    is  => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

has 'db_path' => (
    is      => 'rw',
    isa     => 'Str',
    default => '../CPAN-meta.sqlite',
);

has 'module_rs' => (
    is      => 'rw',
    default => sub {
        my $self = shift;
        return my $rs
            = $self->schema->resultset( 'MetaCPAN::Schema::Result::Module' );
    },
);

has 'pkg_index' => (
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
);

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
            pauseid   => $d->cpanid,
            dist      => $d->dist,
            distvname => $d->distvname,
        };
    }

    return \%index;

}

sub dist {

    my $self = shift;
    my $name = shift;
    $name =~ s{::}{-}g;

    return MetaCPAN::Dist->new( name => $name,
        module_rs => $self->module_rs );

}

sub populate {

    my $self = shift;

    my $index = $self->pkg_index;
    my $count = 0;
    my $every = 999;
    $self->module_rs->delete;

    my $inserts = 0;
    my @rows    = ();
    foreach my $name ( sort keys %{$index} ) {

        my $module = $index->{$name};
        my %create = (
            name         => $name,
            download_url => 'http://cpan.metacpan.org/authors/id/'
                . $module->{archive},
            release_date => $self->pkg_datestamp( $module->{archive} ),
        );

        my @cols = ( 'archive', 'pauseid', 'version', 'dist', 'distvname' );
        foreach my $col ( @cols ) {
            $create{$col} = $module->{$col};
        }

        push @rows, \%create;
        if ( every( $every ) ) {
            $self->module_rs->populate( \@rows );
            $inserts += $every;
            @rows = ();
            say "$inserts rows inserted";
        }
    }

    if ( scalar @rows ) {
        $self->module_rs->populate( \@rows );
        $inserts += scalar @rows;
    }

    return $inserts;

}

sub pkg_datestamp {

    my $self      = shift;
    my $archive   = shift;
    my $dist_file = "/home/cpan/CPAN/authors/id/$archive";
    my $date      = ( stat( $dist_file ) )[9];
    return DateTime::Format::Epoch::Unix->parse_datetime( $date )->iso8601;

}

1;
