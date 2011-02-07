package MetaCPAN;

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

use MetaCPAN::Dist;
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

    return MetaCPAN::Dist->new( distvname => $self->distvname, );

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

sub pkg_datestamp {

    my $self      = shift;
    my $archive   = shift;
    my $dist_file = "/home/cpan/CPAN/authors/id/$archive";
    my $date      = ( stat( $dist_file ) )[9];
    return DateTime::Format::Epoch::Unix->parse_datetime( $date )->iso8601;

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

sub map_author {

    my $self = shift;
    return $self->es->put_mapping(
        index => ['cpan'],
        type  => 'author',

        #_source => { compress => 1 },
        properties => {
            accepts_donations            => { type => "string" },
            amazon_author_profile        => { type => "string" },
            author                       => { type => "string" },
            author_dir                   => { type => "string" },
            blog_feed                    => { type => "string" },
            blog_url                     => { type => "string" },
            books                        => { type => "string" },
            cats                         => { type => "string" },
            city                         => { type => "string" },
            country                      => { type => "string" },
            delicious_username           => { type => "string" },
            dogs                         => { type => "string" },
            email                        => { type => "string" },
            facebook_public_profile      => { type => "string" },
            github_username              => { type => "string" },
            gravatar_url                 => { type => "string" },
            irc_nick                     => { type => "string" },
            linkedin_public_profile      => { type => "string" },
            name                         => { type => "string" },
            openid                       => { type => "string" },
            oreilly_author_profile       => { type => "string" },
            pauseid                      => { type => "string" },
            paypal_address               => { type => "string" },
            perlmongers                  => { type => "string" },
            perlmongers_url              => { type => "string" },
            perlmonks_username           => { type => "string" },
            region                       => { type => "string" },
            slideshare_url               => { type => "string" },
            slideshare_username          => { type => "string" },
            stackoverflow_public_profile => { type => "string" },
            twitter_username             => { type => "string" },
            website                      => { type => "string" },
            youtube_channel_url          => { type => "string" },
        },

    );

}

sub map_dist {

    my $self = shift;

    return $self->es->put_mapping(
        index => ['cpan'],
        type  => 'dist',

        properties => {
            abstract     => { type => "string" },
            archive      => { type => "string" },
            author       => { type => "string" },
            distvname    => { type => "string" },
            download_url => { type => "string" },
            name         => { type => "string" },

            #meta         => { type => "object" },
            name         => { type => "string" },
            release_date => { type => "date" },
            source_url   => { type => "string" },
            version      => { type => "string" },
        }
    );

}

sub map_module {

    my $self = shift;
    return $self->es->put_mapping(
        index => ['cpan'],
        type  => 'module',

        #_source => { compress => 1 },
        properties => {
            abstract     => { type => "string" },
            archive      => { type => "string" },
            author       => { type => "string" },
            distname     => { type => "string" },
            distvname    => { type => "string" },
            download_url => { type => "string" },
            name         => { type => "string" },
            release_date => { type => "date" },
            source_url   => { type => "string" },
            version      => { type => "string" },
        }
    );

}

sub map_pod {

    my $self = shift;
    return $self->es->put_mapping(
        index      => ['cpan'],
        type       => 'pod',
        properties => {
            html     => { type => "string" },
            pure_pod => { type => "string" },
            text     => { type => "string" },
        },
    );

}

sub map_cpanratings {

    my $self = shift;
    return $self->es->put_mapping(
        index      => ['cpan'],
        type       => 'cpanratings',
        properties => {
            dist         => { type => "string" },
            rating       => { type => "string" },
            review_count => { type => "string" },
        },

    );

}

sub map_perlmongers {

    my $self = shift;
    return $self->es->put_mapping(
        index      => ['cpan'],
        type       => 'perlmongers',
        properties => {
            city      => { type       => "string" },
            continent => { type       => "string" },
            email     => { properties => { type => { type => "string" } } },
            inception_date =>
                { format => "dateOptionalTime", type => "date" },
            latitude => { type => "object" },
            location => {
                properties => {
                    city      => { type => "string" },
                    continent => { type => "string" },
                    country   => { type => "string" },
                    latitude  => { type => "string" },
                    longitude => { type => "string" },
                    region    => { type => "object" },
                    state     => { type => "string" },
                },
            },
            longitude    => { type => "object" },
            mailing_list => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            name   => { type => "string" },
            pm_id  => { type => "string" },
            region => { type => "string" },
            state  => { type => "object" },
            status => { type => "string" },
            tsar   => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            web => { type => "string" },
        },

    );

}

sub put_mappings {

    my $self  = shift;
    my @types = qw( author cpanratings dist module pod );

    foreach my $type ( @types ) {
        $self->es->delete_mapping(
            index => ['cpan'],
            type  => $type,
        );
    }

    $self->map_author;
    $self->map_cpanratings;
    $self->map_dist;
    $self->map_module;
    $self->map_pod;

    return;

}

1;

=pod

=head2 check_db

Wipes out SQLite db if that option has been passed.

=head2 dist

Returns a MetaCPAN::Dist object.  Requires distvname() to have been set.

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
