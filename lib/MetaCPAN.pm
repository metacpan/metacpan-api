package MetaCPAN;
# ABSTRACT: MetaCPAN
use Modern::Perl;
use Moose;
with 'MooseX::Getopt';

with 'MetaCPAN::Role::Common';
with 'MetaCPAN::Role::DB';

use Archive::Tar;
use CPAN::DistnameInfo;
use Data::Dump qw( dump );
use DateTime::Format::Epoch::Unix;
use ElasticSearch;
use Every;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);

use MetaCPAN::Script::Dist;
use MetaCPAN::Schema;

has 'cpan' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

has 'db_path' => (
    is      => 'rw',
    isa     => 'Str',
    default => '../CPAN-meta.sqlite',
);

has 'distvname' => (
    is  => 'rw',
    isa => 'Str',
);

has 'dist_name' => (
    is  => 'rw',
    isa => 'Str',
);

has 'dist_like' => (
    is  => 'rw',
    isa => 'Str',
);

has 'pkg_index' => (
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
);

has 'refresh_db' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'reindex' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
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

    return MetaCPAN::Script::Dist->new( distvname => $self->distvname, );

}

sub populate {

    my $self  = shift;
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

sub check_db {

    my $self = shift;
    return if !$self->refresh_db;

    say "resetting db" if $self->debug;

    my $dbh = $self->schema->storage->dbh;
    $dbh->do( "DELETE FROM module" );
    $dbh->do( "VACUUM" );

    return $self->populate

}


1;

=pod

=head2 check_db

Wipes out SQLite db if that option has been passed.

=head2 dist

Returns a MetaCPAN::Script::Dist object.  Requires distvname() to have been set.

=head2 map_author

Define ElasticSearch /cpan/author mapping.

=head2 map_cpanratings

Define ElasticSearch /cpan/cpanratings mapping.

=head2 map_dist

Define ElasticSearch /cpan/dist mapping.

=head2 map_module

Define ElasticSearch /cpan/module mapping.

=head2 map_perlmongers

Define ElasticSearch /cpan/perlmongers mapping.

=head2 map_pod

Define ElasticSearch /cpan/pod mapping.

=head2 put_mappings

Process all of the applicable mappings.

=head2 pkg_datestamp

Returns the file creation date for a distribution.

=head2 open_pkg_index

Returns an IO::Uncompress::AnyInflate object

=head2 populate

Populates the SQLite database

=cut
