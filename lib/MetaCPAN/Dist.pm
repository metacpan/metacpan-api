package MetaCPAN::Dist;

use Archive::Tar;
use Moose;
use Modern::Perl;
use Data::Dump qw( dump );
use Devel::SimpleTrace;
use POSIX qw(ceil);
use Try::Tiny;

use MetaCPAN::Pod::XHTML;

with 'MetaCPAN::Role::Author';
with 'MetaCPAN::Role::Common';
with 'MetaCPAN::Role::DB';

has 'archive_parent' => ( is => 'rw', );

has 'name' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'file' => ( is => 'rw', );

has 'metadata' => (
    is         => 'rw',
    isa        => 'MetaCPAN::Schema::Result::Module',
    lazy_build => 1
);

has 'module' => ( is => 'rw', isa => 'MetaCPAN::Module' );

has 'module_rs' => ( is => 'rw' );

has 'pm_name' => (
    is         => 'rw',
    lazy_build => 1,
);

has 'files' => (
    is         => 'ro',
    isa        => "HashRef",
    lazy_build => 1,
);

has 'inserts' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

has 'tar' => (
    is         => 'rw',
    lazy_build => 1,
);

sub _build_path {
    my $self = shift;
    return $self->meta->archive;
}

=head2 archive_path

Full file path to module archive.

=cut

sub archive_path {

    my $self = shift;
    return $self->minicpan . "/authors/id/" . $self->metadata->archive;

}

=head2 process

Do the heavy lifting here.  First take an educated guess at where the module
should be.  After that, look at every available file to find a match.

=cut

sub process {

    my $self    = shift;
    my $success = 0;

    return 0 if !$self->tar;

    my $module_rs = $self->modules;

    my @modules = ();
    while ( my $found = $module_rs->next ) {
        push @modules, $found;
    }

MODULE:

    #while ( my $found = $module_rs->next ) {
    foreach my $found ( @modules ) {

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

    if ( !$self->inserts && $self->debug ) {
        warn $self->name . " no success" . "!" x 20;
        return;
    }

    $self->tar->clear if $self->tar;

    return;

}

=head2 modules

We only care about modules which are in the very latest version of the distro.
For example, the minicpan (and CPAN) indices, show something like this:

Moose::Meta::Attribute::Native     1.17  D/DR/DROLSKY/Moose-1.17.tar.gz
Moose::Meta::Attribute::Native::MethodProvider::Array 1.14  D/DR/DROLSKY/Moose-1.14.tar.gz

We don't care about modules which are no longer included in the latest
distribution, so we'll only import POD from the highest version number of any
distro we're searching on.

=cut

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

=head2 process_cookbooks

Because manuals and cookbook pages don't appear in the minicpan index, they
were passed over previous to 1.0.2

This should be run on any files left over in the distribution.

Distributions which have .pod files outside of lib folders will be skipped,
since there's often no clear way of discerning which modules (if any) those
docs explicitly pertain to.

=cut

sub process_cookbooks {

    my $self = shift;
    say ">" x 20 . "looking for cookbooks" if $self->debug;

    foreach my $file ( sort keys %{ $self->files } ) {
        next if ( $file !~ m{\Alib(.*)\.pod\z} );

        my $module_name = $self->file2mod( $file );

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

    return 0 if !exists $self->files->{$filename};

    # not every module contains POD
    my $content
        = $self->tar->get_content( $self->archive_parent . $filename );
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
    delete $self->files->{$filename};

    return $content;

}

sub parse_pod {

    my $self        = shift;
    my $module_name = shift;
    my $file        = shift;

    my $content = $self->get_content( $module_name, $file );

    return if !$content;

    my $parser = MetaCPAN::Pod::XHTML->new();

    $parser->index( 1 );
    $parser->html_header('');
    $parser->html_footer('');
    $parser->perldoc_url_prefix( '' );
    
    my $xhtml = "";
    $parser->output_string( \$xhtml );
    $parser->parse_string_document( $content );

    $self->metadata->xhtml_pod( $xhtml );
    $self->metadata->update;
    return 1;

}

sub _build_files {

    my $self = shift;
    my $tar  = $self->tar;

    eval { $tar->read( $self->archive_path ) };
    if ( $@ ) {
        warn $@;
        return [];
    }

    my @files = $tar->list_files;
    my %files = ();
    $self->archive_parent( $self->metadata->distvname . '/' );

    if ( $self->debug ) {
        my %cols = $self->metadata->get_columns;
        say dump( \%cols ) if $self->debug;
    }

    if ( @files ) {

        # some dists expand to: ./AFS-2.6.2/src/Utils/Utils.pm
        if ( $files[0] =~ m{\A\.\/} ) {
            my $parent = $self->archive_parent;
            $self->archive_parent( './' . $parent );
        }
    }

    say "parent " . ":" x 20 . $self->archive_parent if $self->debug;

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
    my $metadata
        = $self->meta_index->schema->resultset(
        'MetaCPAN::Schema::Result::Module' )
        ->search( { dist => $self->name } )->first;

    return $metadata;

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
    my @module_parts = split( "::", $self->metadata->name );
    return pop( @module_parts );
}

1;
