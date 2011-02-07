package MetaCPAN::Dist;

use Archive::Tar;
use Archive::Tar::Wrapper;
use Data::Dump qw( dump );
use Devel::SimpleTrace;
use File::Slurp;
use Moose;
use MooseX::Getopt;
use Modern::Perl;

#use Parse::CPAN::Meta qw( load_yaml_string );
use Pod::POM;
use Pod::POM::View::Pod;
use Pod::Text;
use Try::Tiny;
use WWW::Mechanize::Cached;
use YAML;

with 'MooseX::Getopt';

use MetaCPAN::Pod::XHTML;

with 'MetaCPAN::Role::Common';
with 'MetaCPAN::Role::DB';

has 'archive_parent' => ( is => 'rw', );

has 'dist_name' => ( is => 'rw', required => 1, );

has 'distvname' => (
    is       => 'rw',
    required => 1,
);

has 'es_inserts' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

has 'files' => (
    is         => 'ro',
    isa        => "HashRef",
    lazy_build => 1,
);

has 'max_bulk' => ( is => 'rw', default    => 50 );
has 'mech'     => ( is => 'rw', lazy_build => 1 );
has 'module' => ( is => 'rw', isa => 'MetaCPAN::Schema::Result::Module' );

has 'module_rs' => ( is => 'rw' );

has 'pm_name' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'processed' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'reindex' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has 'tar' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'tar_class' => (
    is      => 'rw',
    default => 'Archive::Tar',
);

has 'tar_wrapper' => (
    is         => 'rw',
    lazy_build => 1,
);

sub archive_path {

    my $self = shift;
    return $self->cpan . "/authors/id/" . $self->module->archive;

}

sub process {

    my $self    = shift;
    my $success = 0;

    say "reindex? " . $self->reindex;

    # skip dists already in the index
    if ( !$self->reindex && $self->is_indexed ) {
        say '-' x 200 . 'skipped: ' . $self->distvname;
        return;
    }

    my $module_rs
        = $self->module_rs->search( { distvname => $self->distvname } );

    my @modules = ();
    while ( my $found = $module_rs->next ) {
        push @modules, $found;
    }

MODULE:

    #while ( my $found = $module_rs->next ) {
    foreach my $found ( @modules ) {

        $self->module( $found );
        say "checking dist " . $found->name if $self->debug;

        # take an educated guess at the correct file before we go through the
        # entire list some dists (like BioPerl, have no lib folder) Some
        # modules, like Text::CSV_XS have no lib folder, but have the module
        # in the top directory. In this case, CSV_XS.pm

        foreach my $source_folder ( 'lib/', '' ) {

            my $base_guess = $source_folder . $found->name;
            $base_guess =~ s{::}{/}g;

            my @parts = split( "::", $found->name );
            my $last_chance = pop @parts;

            foreach my $attempt ( $base_guess, $last_chance ) {

                foreach my $extension ( '.pm', '.pod' ) {
                    my $guess = $attempt . $extension;
                    say "*" x 10 . " about to guess: $guess" if $self->debug;
                    if ( $self->index_pod( $found->name, $guess ) ) {
                        say "*" x 10 . " found guess: $guess" if $self->debug;
                        ++$success;
                        next MODULE;
                    }

                }
            }

        }

    }

    $self->process_cookbooks;
    $self->index_dist;

    if ( $self->es_inserts ) {
        my $result = $self->insert_bulk;
    }

    elsif ( $self->debug ) {
        warn " no success" . "!" x 20;
        return;
    }

    $self->tar->clear if $self->tar;

    return;

}

sub process_cookbooks {

    my $self = shift;
    say ">" x 20 . "looking for cookbooks" if $self->debug;

    foreach my $file ( sort keys %{ $self->files } ) {
        next if ( $file !~ m{\Alib(.*)\.pod\z} );

        my $module_name = $self->file2mod( $file );

        # update ->module for each cookbook file.  otherwise it gets indexed
        # under the wrong module name
        my %cols = $self->module->get_columns;
        delete $cols{xhtml_pod};
        delete $cols{id};
        $cols{name} = $module_name;
        $cols{file} = $file;

        $self->module( $self->module_rs->find_or_create( \%cols ) );
        my %new_cols = $self->module->get_columns;

        my $success = $self->index_pod( $module_name, $file );
        say '=' x 20 . "cookbook ok: " . $file if $self->debug;
    }

    return;

}

sub push_inserts {

    my $self    = shift;
    my $inserts = shift;

    push @{ $self->es_inserts }, @{$inserts};
    if ( scalar @{ $self->es_inserts } > $self->max_bulk ) {
        $self->insert_bulk();
    }

    return;

}

sub insert_bulk {

    my $self = shift;

    #$self->es->transport->JSON->convert_blessed(1);

    say '#' x 40;
    say 'inserting bulk: ' . scalar @{ $self->es_inserts };
    say '#' x 40;

    my $result = try {
        $self->es->bulk( $self->es_inserts );
    }
    catch {
        say '+' x 40;
        say "caught error: $_";
        say "TIMEOUT! Individual inserts beginning";
        say '+' x 40;
        foreach my $insert ( @{ $self->es_inserts } ) {
            my $result = try { $self->es->bulk( $insert ); }
            catch {
                say '+' x 40;
                say "caught error: $_";
                say "FAILED: \n" . dump( $insert );
                say '+' x 40;
            };
            if ( $result ) {
                say '=' x 40;
                say "SUCCESS with individual insert";
                say '=' x 40;
            }
        }
    };

    say dump( $result ) if $self->debug;
    $self->es_inserts( [] );

}

sub get_abstract {

    my $self   = shift;
    my $parser = Pod::POM->new;
    my $pom    = $parser->parse_text( shift ) || return;

    foreach my $s ( @{ $pom->head1 } ) {
        if ( $s->title eq 'NAME' ) {
            my $content = $s->content;
            $content =~ s{\A.*\-\s}{};
            $content =~ s{\s*\z}{};

            # MOBY::Config has more than one POD section in the abstract after
            # parsing Should have a closer look and file bug with Pod::POM
            # It also contains newlines in the actual source
            $content =~ s{=head.*}{}xms;
            $content =~ s{\n}{}gxms;

            return ( $pom, $content );
        }
    }

    return ( $pom );
}

sub get_content {

    my $self        = shift;
    my $module_name = shift;
    my $filename    = shift;
    my $pm_name     = $self->pm_name;

    return if !exists $self->files->{$filename};

    # not every module contains POD
    my $file    = $self->archive_parent . $filename;
    my $content = undef;

    if ( $self->tar_class eq 'Archive::Tar' ) {
        $content
            = $self->tar->get_content( $self->archive_parent . $filename );
    }
    else {
        my $location = $self->tar_wrapper->locate( $file );

        if ( !$location ) {
            say "skipping: $file does not found in archive" if $self->debug;
            return;
        }

        $content = read_file( $location );
    }

    if ( !$content || $content !~ m{=head} ) {
        say "skipping -- no POD    -- $filename" if $self->debug;
        delete $self->files->{$filename};
        return;
    }

    if ( $filename !~ m{\.pod\z} && $content !~ m{package\s*$module_name} ) {
        say "skipping -- not the correct package name" if $self->debug;
        return;
    }

    say "got pod ok: $filename " if $self->debug;
    return $content;

}

sub index_pod {

    my $self        = shift;
    my $module_name = shift;
    my $file        = shift;
    my $module      = $self->module;

    my $content = $self->get_content( $module_name, $file );
    say $file if $self->debug;

    if ( !$content ) {
        say "No content found for $file" if $self->debug;
        return;
    }

    $module->file( $file );
    $module->update;

    my ( $pom, $abstract ) = $self->get_abstract( $content );

    my %pod_insert = (
        index => {
            index => 'cpan',
            type  => 'pod',
            id    => $module_name,
            data  => {
                html     => $self->pod2html( $content ),
                text     => $self->pod2txt( $content ),
                pure_pod => Pod::POM::View::Pod->print( $pom ),
            },
        }
    );

    $self->index_module( $file, $abstract );

    $self->push_inserts( [ \%pod_insert ] );

    # if this line is commented, some pod (like Dancer docs) gets skipped
    delete $self->files->{$file};
    push @{ $self->processed }, $file;

    return 1;

}

sub index_dist {

    my $self       = shift;
    my $module     = $self->module;
    my $source_url = $self->source_url( '' );
    chop $source_url;

    my $data = {
        name       => $self->dist_name,
        author     => $module->pauseid,
        source_url => $source_url
    };

    my $res = $self->mech->get( $self->source_url( 'META.yml' ) );

    if ( $res->code == 200 ) {

        # some meta files are missing a trailing newline
        my $meta_yml = try {

            #Parse::CPAN::Meta->load_yaml_string( $res->content . "\n" );
            Load( $res->content . "\n" );
        }
        catch {
            warn "caught error: $_";
            undef;
        };

        if ( exists $meta_yml->{provides} ) {
            foreach my $key ( keys %{ $meta_yml->{provides} } ) {
                if ( exists $meta_yml->{provides}->{$key}->{version} ) {
                    $meta_yml->{provides}->{$key}->{version} .= '';
                }
            }
        }
        if ( exists $meta_yml->{version} ) {
            $meta_yml->{version} .= '';
        }

        #$data->{meta} = $meta_yml;

        $data->{abstract} = $meta_yml->{abstract};

    }

    my @cols = ( 'download_url', 'archive', 'release_date', 'version',
        'distvname' );

    foreach my $col ( @cols ) {
        $data->{$col} = $module->$col;
    }

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'dist',
            id    => $self->dist_name,
            data  => $data,
        }
    );

    $self->push_inserts( [ \%es_insert ] );

    return;

}

sub index_module {

    my $self      = shift;
    my $file      = shift;
    my $abstract  = shift;
    my $module    = $self->module;
    my $dist_name = $module->distvname;
    $dist_name =~ s{\-\d.*}{}g;

    my $src_url = $self->source_url( $module->file );

    my $data = {
        name       => $module->name,
        source_url => $src_url,
        distname   => $dist_name,
        author     => $module->pauseid,
    };
    my @cols
        = ( 'download_url', 'archive', 'release_date', 'version', 'distvname',
        );

    foreach my $col ( @cols ) {
        $data->{$col} = $module->$col;
    }

    $data->{abstract} = $abstract;

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'module',
            id    => $module->name,
            data  => $data,
        }
    );

    say dump( \%es_insert ) if $self->debug;
    $self->push_inserts( [ \%es_insert ] );

}

sub get_files {

    my $self  = shift;
    my @files = ();

    if ( $self->tar_class eq 'Archive::Tar' ) {
        my $tar = $self->tar;
        eval { $tar->read( $self->archive_path ) };
        if ( $@ ) {
            warn $@;
            return [];
        }

        @files = $tar->list_files;
    }

    else {
        for my $entry ( @{ $self->tar_wrapper->list_all() } ) {
            my ( $tar_path, $real_path ) = @$entry;
            push @files, $tar_path;
        }
    }

    return \@files;

}

sub is_indexed {

    my $self    = shift;
    my $success = 0;
    say "looking for " . $self->dist_name if $self->debug;
    my $get = try {
        $self->es->get(
            index => 'cpan',
            type  => 'dist',
            id    => $self->dist_name,
        );
    };

    if ( exists $get->{_source}->{distvname}
        && $get->{_source}->{distvname} eq $self->distvname )
    {
        return 1;
    }

    return $success;

}

sub pod2html {

    my $self    = shift;
    my $content = shift;
    my $parser  = MetaCPAN::Pod::XHTML->new();

    $parser->index( 1 );
    $parser->html_header( '' );
    $parser->html_footer( '' );
    $parser->perldoc_url_prefix( '' );
    $parser->no_errata_section( 1 );

    my $html = "";
    $parser->output_string( \$html );
    $parser->parse_string_document( $content );

    return $html;

}

sub pod2txt {

    my $self    = shift;
    my $content = shift;

    my $parser = Pod::Text->new( sentence => 0, width => 78 );

    my $text = "";
    $parser->output_string( \$text );
    $parser->parse_string_document( $content );

    return $text;

}

sub _build_files {

    my $self  = shift;
    my $files = $self->get_files;
    my @files = @{$files};
    return {} if scalar @files == 0;

    my %files = ();

    $self->set_archive_parent( $files );

    if ( $self->debug ) {
        my %cols = $self->module->get_columns;
        say dump( \%cols ) if $self->debug;
    }

    foreach my $file ( @files ) {
        if ( $file =~ m{\.(pod|pm)\z}i ) {

            my $parent = $self->archive_parent;
            $file =~ s{\A$parent}{};

            next if $file =~ m{\At\/};    # avoid test modules

            # avoid POD we can't properly name
            next if $file =~ m{\.pod\z} && $file !~ m{\Alib\/};

            $files{$file} = 1;
        }
    }

    say dump( \%files ) if $self->debug;
    return \%files;

}

sub _build_mech {

    my $self = shift;
    return WWW::Mechanize::Cached->new( autocheck => 0 );

}

sub _build_metadata {

    my $self = shift;
    return $self->module_rs->search( { distvname => $self->distvname } )
        ->first;

}

sub _build_path {
    my $self = shift;
    return $self->meta->archive;
}

sub _build_pod_name {
    my $self = shift;
    return $self->_module_root . '.pod';
}

sub _build_pm_name {
    my $self = shift;
    return $self->_module_root . '.pm';
}

sub _build_tar {

    my $self = shift;
    say "archive path: " . $self->archive_path if $self->debug;
    my $tar = undef;
    try { $tar = Archive::Tar->new( $self->archive_path ) };

    if ( !$tar ) {
        say "*" x 30 . ' no tar object created for ' . $self->archive_path;
        return 0;
    }

    if ( $tar->error ) {
        say "*" x 30 . ' tar error: ' . $tar->error;
        return 0;
    }

    return $tar;

}

sub _build_tar_wrapper {

    my $self = shift;
    my $arch = Archive::Tar::Wrapper->new();

    $arch->read( $self->archive_path );

    $arch->list_reset();
    return $arch;

}

sub _module_root {
    my $self = shift;
    my @module_parts = split( "::", $self->module->name );
    return pop( @module_parts );
}

sub set_archive_parent {

    my $self  = shift;
    my $files = shift;

    # is there one parent folder for all files?
    my %parent = ();
    foreach my $file ( @{$files} ) {
        my @parts = split "/", $files->[0];
        my $top = shift @parts;

        # some dists expand to: ./AFS-2.6.2/src/Utils/Utils.pm
        $top .= '/' . shift @parts if ( $top eq '.' );
        $parent{$top} = 1;
    }

    my @folders = keys %parent;

    if ( scalar @folders == 1 ) {
        $self->archive_parent( $folders[0] . '/' );
    }

    say "parent " . ":" x 20 . $self->archive_parent if $self->debug;

    return;

}

sub source_url {

    my $self = shift;
    my $file = shift;
    return sprintf( 'http://search.metacpan.org/source/%s/%s/%s',
        $self->module->pauseid, $self->module->distvname, $file );

}

1;

=pod

=head1 SYNOPSIS

We only care about modules which are in the very latest version of the distro.
For example, the minicpan (and CPAN) indices, show something like this:

Moose::Meta::Attribute::Native     1.17  D/DR/DROLSKY/Moose-1.17.tar.gz
Moose::Meta::Attribute::Native::MethodProvider::Array 1.14  D/DR/DROLSKY/Moose-1.14.tar.gz

We don't care about modules which are no longer included in the latest
distribution, so we'll only import POD from the highest version number of any
distro we're searching on.

=head2 archive_path

Full file path to module archive.

=head2 distvname

The distvname of the dist which you'd like to index.  eg: Moose-1.21

=head2 es_inserts

An ARRAYREF of data to insert/update in the ElasticSearch index.  Since bulk
inserts are significantly faster, it's to our advantage to push all insert
data onto this array and then handle all of the changes at once.

=head2 files

A HASHREF of files which may contain modules or POD.  This list ignores files
which obviously aren't helpful to us.

=head2 get_abstract( $string )

Parses out the module abtract from the head1 "NAME" section.

=head2 get_content

Returns the contents of a file in the dist

=head2 get_files

Returns an ARRAYREF of all files in the dist

=head2 index_dist

Sets up the ES insert for this dist

=head2 index_module

Sets up the ES insert for a module.  Will be called once for each module or
POD file contained in the dist.

=head2 index_pod

Sets up the ES insert for the POD. Will be called once for each module or
POD file contained in the dist.

=head2 insert_bulk

Handles bulk inserts. If the bulk insert fails, we attempt to reindex each
document individually.

=head2 is_indexed

Checks to see if the distvname in question already exists in the index. This
is useful for nightly updates, which only need to deal with dists which
haven't already been inserted.

=head2 module_rs

A shortcut for getting a resultset of modules listed in the SQLite db

=head2 pod2html( $string )

Returns XHTML formatted doccumentation. These are used as the basis for
search.metacpan.org

=head2 pod2txt( $string )

Returns plain text documentation. The plain text will be used for full-text
searches.

=head2 process

Do the heavy lifting here.  First take an educated guess at where the module
should be.  After that, look at every available file to find a match.

=head2 process_cookbooks

Because manuals and cookbook pages don't appear in the minicpan index, they
were passed over previous to 1.0.2

This should be run on any files left over in the distribution.

Distributions which have .pod files outside of lib folders will be skipped,
since there's often no clear way of discerning which modules (if any) those
docs explicitly pertain to.

=head2 push_inserts( [ $insert1, $insert2 ] )

Manages document insertion. If the max bulk insert number has been reached, an
insert is performed. If not, we'll push push these items onto the list.

=head2 set_archive_parent

The folder name of the top level of the archive is not always predictable.
This method tries to find the correct name.

=head2 source_url

Returns a full URL to a file from the dist, in an uncompressed form.

=head2 tar

Returns an Archive::Tar object

=head2 tar_class( 'Archive::Tar|Archive::Tar::Wrapper' )

Choose the module you'd like to use for unarchiving. Archive::Tar unzips into
memory while Archive::Tar::Wrapper unzips to disk. Defaults to Archive::Tar,
which is much faster.

=head2 tar_wrapper

Returns an Archive::Tar::Wrapper object

=cut

