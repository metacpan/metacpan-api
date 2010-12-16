package MetaCPAN::Dist;

use Archive::Tar;
use Archive::Tar::Wrapper;
use File::Slurp;
use Moose;
use MooseX::Getopt;
use Modern::Perl;
use Data::Dump qw( dump );
use Try::Tiny;

use MetaCPAN::Pod::XHTML;

with 'MetaCPAN::Role::Author';
with 'MetaCPAN::Role::Common';
with 'MetaCPAN::Role::DB';

has 'archive_parent' => ( is => 'rw', );

has 'es_inserts' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

has 'file' => ( is => 'rw', );

has 'files' => (
    is         => 'ro',
    isa        => "HashRef",
    lazy_build => 1,
);

has 'module' => ( is => 'rw', isa => 'MetaCPAN::Schema::Result::Module' );

has 'module_rs' => ( is => 'rw' );

has 'name' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'pm_name' => (
    is         => 'rw',
    lazy_build => 1,
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

sub _build_path {
    my $self = shift;
    return $self->meta->archive;
}

sub archive_path {

    my $self = shift;
    return $self->cpan . "/authors/id/" . $self->module->archive;

}

sub process {

    my $self    = shift;
    my $success = 0;

    #return 0 if !$self->tar;

    my $module_rs = $self->module_rs->search({ dist => $self->name });

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
        # entire list

        my $base_guess = 'lib/' . $found->name;
        $base_guess =~ s{::}{/}g;

        foreach my $extension ( '.pm', '.pod' ) {
            my $guess = $base_guess . $extension;
            say "*" x 10 . " about to guess: $guess" if $self->debug;
            if ( $self->parse_pod( $found->name, $guess ) ) {
                say "*" x 10 . " found guess: $guess" if $self->debug;
                ++$success;
                next MODULE;
            }

        }

    FILE:
        foreach my $file ( sort keys %{ $self->files } ) {
            say "checking files: $file " if $self->debug;
            next FILE if !$self->parse_pod( $found->name, $file );

            say "found: $file ";
            ++$success;
            next MODULE;
        }

    }

    $self->process_cookbooks;

    $self->index_dist;

    if ( $self->es_inserts ) {
        my $result = $self->es->bulk( $self->es_inserts );
    }

    elsif ( $self->debug ) {
        warn $self->name . " no success" . "!" x 20;
        return;
    }

    $self->tar->clear if $self->tar;

    return;

}

sub modules {

    my $self = shift;
    my $name = $self->name;
    $name =~ s{::}{-}g;
    $self->name( $name );

    # I'm sure there is a better way of doing this (GROUP BY?)
    my $latest = $self->module_rs->search( { dist => $self->name },
        { order_by => 'distvname DESC' } )->first;

    return $self->module_rs->search( { distvname => $latest->distvname } );

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
 
        $self->module( $self->module_rs->find_or_create(\%cols) );
        my %new_cols = $self->module->get_columns;
        
        my $success = $self->parse_pod( $module_name, $file );
        say '=' x 20 . "cookbook ok: " . $file if $self->debug;
    }

    return;

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

    say "got pod ok: $filename ";
    # if this line is uncommented some pod, like Dancer docs gets skipped
    #delete $self->files->{$filename};

    return $content;

}

sub parse_pod {

    my $self        = shift;
    my $module_name = shift;
    my $file        = shift;
    my $module      = $self->module;

    my $content = $self->get_content( $module_name, $file );
    say $file;

    if ( !$content ) {
        say "No content found for $file" if $self->debug;
        return;
    }

    my $parser = MetaCPAN::Pod::XHTML->new();

    $parser->index( 1 );
    $parser->html_header( '' );
    $parser->html_footer( '' );
    $parser->perldoc_url_prefix( '' );

    my $xhtml = "";
    $parser->output_string( \$xhtml );
    $parser->parse_string_document( $content );

    $module->xhtml_pod( $xhtml );
    $module->file( $file );
    $module->update;

    my %pod_insert = (
        index => {
            index => 'cpan',
            type  => 'pod',
            id    => $module_name,
            data  => { pod => $xhtml },
        }
    );

    #my %cols = $module->get_columns;
    #say dump( \%cols );

    $self->index_module( $file );

    push @{ $self->es_inserts }, \%pod_insert;

    return 1;

}

sub index_dist {

    my $self      = shift;
    my $module    = $self->module;
    my $dist_name = $module->distvname;
    $dist_name =~ s{\-\d.*}{}g;

    my $data = { name => $dist_name, author => $module->pauseid };
    my @cols = ( 'download_url', 'archive', 'release_date', 'version',
        'distvname' );

    foreach my $col ( @cols ) {
        $data->{$col} = $module->$col;
    }

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'dist',
            id    => $dist_name,
            data  => $data,
        }
    );

    push @{ $self->es_inserts }, \%es_insert;

}

sub index_module {

    my $self      = shift;
    my $file      = shift;
    my $module    = $self->module;
    my $dist_name = $module->distvname;
    $dist_name =~ s{\-\d.*}{}g;

    my $src_url = sprintf( 'http://search.metacpan.org/source/%s/%s/%s',
        $module->pauseid, $module->distvname, $module->file );

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

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'module',
            id    => $module->name,
            data  => $data,
        }
    );

    #say dump( \%es_insert );
    push @{ $self->es_inserts }, \%es_insert;

}

sub get_files {
    
    my $self = shift;
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

sub _build_metadata {

    my $self = shift;
    return $self->module_rs->search( { dist => $self->name } )->first;

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

sub _build_pm_name {
    my $self = shift;
    return $self->_module_root . '.pm';
}

sub _build_pod_name {
    my $self = shift;
    return $self->_module_root . '.pod';
}

sub _module_root {
    my $self = shift;
    my @module_parts = split( "::", $self->module->name );
    return pop( @module_parts );
}

sub set_archive_parent {
    
    my $self = shift;
    my $files = shift;
    
    # is there one parent folder for all files?
    my %parent = ( );
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

1;

=pod

=head2 archive_path

Full file path to module archive.

=head2 modules

We only care about modules which are in the very latest version of the distro.
For example, the minicpan (and CPAN) indices, show something like this:

Moose::Meta::Attribute::Native     1.17  D/DR/DROLSKY/Moose-1.17.tar.gz
Moose::Meta::Attribute::Native::MethodProvider::Array 1.14  D/DR/DROLSKY/Moose-1.14.tar.gz

We don't care about modules which are no longer included in the latest
distribution, so we'll only import POD from the highest version number of any
distro we're searching on.

=cut

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

=cut


