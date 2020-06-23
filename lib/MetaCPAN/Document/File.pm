package MetaCPAN::Document::File;

use strict;
use warnings;
use utf8;

use Moose;
use ElasticSearchX::Model::Document;

use Encode;
use List::AllUtils qw( any );
use MetaCPAN::Document::Module;
use MetaCPAN::Types qw(Module);
use MetaCPAN::Types::TypeTiny qw(
    Stat ArrayRef Bool Int Maybe Num ScalarRef Str
);
use MetaCPAN::Util qw(numify_version);
use Plack::MIME;
use Pod::Text;
use Try::Tiny qw( catch try );
use URI::Escape ();

Plack::MIME->add_type( '.t'   => 'text/x-script.perl' );
Plack::MIME->add_type( '.pod' => 'text/x-pod' );
Plack::MIME->add_type( '.xs'  => 'text/x-c' );

my @NOT_PERL_FILES = qw(SIGNATURE);

sub BUILD {
    my $self = shift;

    # force building of `mime`
    $self->_build_mime;
}

=head1 PROPERTIES

=head2 deprecated

Indicates file deprecation (the abstract contains "DEPRECATED" or "DEPRECIATED",
or the x_deprecated flag is included in the corresponding "provides" entry in distribution metadata);
it is also set if the entire release is marked deprecated (see L<MetaCPAN::Document::Release#deprecated>).

=cut

has deprecated => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
    writer  => '_set_deprecated',
);

=head2 abstract

Abstract of the documentation (if any). This is built by parsing the
C<NAME> section. It also sets L</documentation> if it succeeds.

=cut

has section => (
    is       => 'ro',
    isa      => Maybe [Str],
    lazy     => 1,
    builder  => '_build_section',
    property => 0,
);

my $RE_SECTION = qr/^\s*(\S+)((\h+-+\h+(.+))|(\r?\n\h*\r?\n\h*(.+)))?/ms;

sub _build_section {
    my $self = shift;

    my $text    = ${ $self->content };
    my $section = MetaCPAN::Util::extract_section( $text, 'NAME' );

    # if it's a POD file without a name section, let's try to generate
    # an abstract and name based on filename
    if ( !$section && $self->path =~ /\.pod$/ ) {
        $section = $self->path;
        $section =~ s{^(lib|pod|docs)/}{};
        $section =~ s{\.pod$}{};
        $section =~ s{/}{::}g;
    }

    return undef unless ($section);
    $section =~ s/^=\w+.*$//mg;
    $section =~ s/X<.*?>//mg;

    return $section;
}

has abstract => (
    required => 1,
    is       => 'ro',
    isa      => Maybe [Str],
    lazy     => 1,
    builder  => '_build_abstract',
    index    => 'analyzed',
);

sub _build_abstract {
    my $self = shift;
    return undef unless ( $self->is_perl_file );

    my $section = $self->section;
    return undef unless $section;

    my $abstract;

    if ( $section =~ $RE_SECTION ) {
        chomp( $abstract = $4 || $6 ) if ( $4 || $6 );
    }
    if ($abstract) {
        $abstract =~ s/^=\w+.*$//xms;
        $abstract =~ s{\r?\n\h*\r?\n\h*.*$}{}xms;
        $abstract =~ s{\n}{ }gxms;
        $abstract =~ s{\s+$}{}gxms;
        $abstract =~ s{(\s)+}{$1}gxms;
        $abstract = MetaCPAN::Util::strip_pod($abstract);
    }
    return $abstract;
}

=head2 id

Unique identifier of the release.
Consists of the L</author>'s pauseid, the release L</name>,
and the file path.
See L<ElasticSearchX::Model::Util/digest>.

=cut

has id => (
    is => 'ro',
    id => [qw(author release path)],
);

=head2 module

An ArrayRef of L<MetaCPAN::Document::Module> objects, that represent
modules defined in that class (i.e. package declarations).

=cut

has module => (
    is              => 'ro',
    isa             => Module,
    type            => 'nested',
    include_in_root => 1,
    coerce          => 1,
    clearer         => 'clear_module',
    writer          => '_set_module',
    lazy            => 1,
    default         => sub { [] },
);

=head2 download_url

B<Required>

Download URL of the release

=cut

has download_url => (
    is       => 'ro',
    required => 1
);

=head2 date

B<Required>

Release date (i.e. C<mtime> of the archive file).

=cut

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
);

=head2 description

Contains the C<DESCRIPTION> section of the POD if any. Will be stripped from
whitespaces and POD commands.

=cut

has description => (
    required => 1,
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_description',
    index    => 'not_analyzed',
);

sub _build_description {
    my $self = shift;
    return undef unless ( $self->is_perl_file );
    my $section
        = MetaCPAN::Util::extract_section( ${ $self->content },
        'DESCRIPTION' );
    return undef unless ($section);

    my $parser = Pod::Text->new;
    my $text   = q{};
    $parser->output_string( \$text );

    try {
        $parser->parse_string_document("=pod\n\n$section");
    }
    catch {
        warn $_;
    };

    return undef unless $text;

    $text =~ s/\s+/ /g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

=head2 distribution

=head2 distribution.analyzed

=head2 distribution.camelcase

Name of the distribution (e.g. C<Some-Module>).

=head2 author

PAUSE ID of the author.

=head2 status

Valid values are C<latest>, C<cpan>, and C<backpan>. The most recent upload
of a distribution is tagged as C<latest> as long as it's not a developer
release, unless there are only developer releases. Everything else is
tagged C<cpan>. Once a release is deleted from PAUSE it is tagged as
C<backpan>.

=cut

has status => ( is => 'ro', required => 1, default => 'cpan' );

=head2 binary

File is binary or not.

=cut

has binary => (
    is       => 'ro',
    isa      => Bool,
    required => 1,
    default  => 0,
);

=head2 authorized

See L</set_authorized>.

=cut

has authorized => (
    required => 1,
    is       => 'ro',
    isa      => Bool,
    default  => 1,
    writer   => '_set_authorized',
);

=head2 maturity

Maturity of the release. This can either be C<released> or C<developer>.
See L<CPAN::DistnameInfo>.

=cut

has maturity => (
    is       => 'ro',
    required => 1,
    default  => 'released',
);

=head2 directory

Return true if this object represents a directory.

=cut

has directory => (
    is       => 'ro',
    required => 1,
    isa      => Bool,
    default  => 0,
);

=head2 documentation

Holds the name for the documentation in this file.

If the file L<is a pod file|/is_pod_file>, the name is derived from the
C<NAME> section. If the file L<is a perl file|/is_perl_file> and the
name from the C<NAME> section matches one of the modules in L</module>,
it returns the name. Otherwise it returns the name of the first module
in L</module>. If there are no modules in the file the documentation is
set to C<undef>.

=cut

has documentation => (
    is        => 'ro',
    isa       => Maybe [Str],
    lazy      => 1,
    index     => 'analyzed',
    builder   => '_build_documentation',
    predicate => 'has_documentation',
    analyzer  => [qw(standard camelcase lowercase edge edge_camelcase)],
    clearer   => 'clear_documentation',
    writer    => '_set_documentation',
);

sub _build_documentation {
    my $self = shift;
    return undef unless ( $self->is_perl_file );

    my $section = $self->section;
    return undef unless $section;

    my $documentation;

    if ( $section =~ $RE_SECTION ) {
        my $name = MetaCPAN::Util::strip_pod($1);
        $documentation = $name if ( $name =~ /^[\w\.:\-_']+$/ );
    }

    $documentation = MetaCPAN::Util::strip_pod($documentation)
        if $documentation;

    return undef unless length $documentation;

    # Modules to be indexed
    my @indexed = grep { $_->indexed } @{ $self->module || [] };

    # This is a Pod file, return its name
    if ( $documentation && $self->is_pod_file ) {
        return $documentation;
    }

    # OR: found an indexed module with the same name
    if ( $documentation && grep { $_->name eq $documentation } @indexed ) {
        return $documentation;
    }

    # OR: found an indexed module with a name
    if ( my ($mod) = grep { defined $_->name } @indexed ) {
        return $mod->name;
    }

    # OR: we have a parsed documentation
    return $documentation if defined $documentation;

    # OR: found ANY module with a name (better than nothing)
    if ( my ($mod) = grep { defined $_->name } @{ $self->module || [] } ) {
        return $mod->name;
    }

    return undef;
}

=head2 suggest

Autocomplete info for documentation.

=cut

has suggest => (
    is => 'ro',

    #    isa     => Maybe [HashRef], # remarked: breaks the suggester
    lazy    => 1,
    builder => '_build_suggest',
);

sub _build_suggest {
    my $self = shift;
    my $doc  = $self->documentation;

    #    return +{} unless $doc; # remarked because of 'isa'
    return unless $doc;

    my $weight = 1000 - length($doc);
    $weight = 0 if $weight < 0;

    return +{
        input   => [$doc],
        payload => { doc_name => $doc },
        weight  => $weight,
    };
}

=head2 indexed

B<Default 0>

Indicates whether the file should be included in the search index or
not. See L</set_indexed> for a more verbose explanation.

=cut

has indexed => (
    required => 1,
    is       => 'ro',
    isa      => Bool,
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        return 0 if $self->is_in_other_files;
        return 0 if !$self->metadata->should_index_file( $self->path );
        return 1;
    },
    writer => '_set_indexed',
);

=head2 level

Level of this file in the directory tree of the release (i.e. C<META.yml>
has a level of C<0>).

=cut

has level => (
    required => 1,
    is       => 'ro',
    isa      => Int,
    lazy     => 1,
    builder  => '_build_level',
);

sub _build_level {
    my $self  = shift;
    my @level = split( /\//, $self->path );
    return @level - 1;
}

=head2 pod

Pure text format of the pod (see L</Pod::Text>). Consecutive whitespaces
are removed to save space and for better snippet previews.

=cut

has pod => (
    required     => 1,
    is           => 'ro',
    isa          => ScalarRef,
    lazy         => 1,
    builder      => '_build_pod',
    index        => 'analyzed',
    not_analyzed => 0,
    store        => 'no',
    term_vector  => 'with_positions_offsets',
);

sub _build_pod {
    my $self = shift;
    return \'' unless ( $self->is_perl_file );

    my $parser = Pod::Text->new( sentence => 0, width => 78 );

    # We don't need to index pod errors.
    $parser->no_errata_section(1);

    my $content = ${ $self->content };

    # The pod parser is very liberal and will "start" a pod document when it
    # sees /^=[a-zA-Z]/ even though it might be binary like /^=F\0?\{/.
    # So munge any lines that might match but are not usual pod directives
    # that people would use (we don't need to index non-regular pod).
    # Also see the test and comments in t/document/file.t for how
    # bizarre constructs are handled.

    $content =~ s/
        # Pod::Simple::parse_string_document() "supports \r, \n ,\r\n"...
        (?:
            \A|\r|\r\n|\n)     # beginning of line
        \K                     # (keep those characters)

        (
        =[a-zA-Z][a-zA-Z0-9]*  # looks like pod
        (?!                    # but followed by something that isn't pod:
              [a-zA-Z0-9]      # more pod chars (the star won't be greedy enough)
            | \s               # whitespace ("=head1 NAME\n", "=item\n")
            | \Z               # end of line or end of doc
        )
        )

    # Prefix (to hide from Pod parser) instead of removing.
    /\0$1/gx;

    my $text = "";
    $parser->output_string( \$text );

    try {
        $parser->parse_string_document($content);
    }
    catch {
        warn $_[0];
    };

    $text =~ s/\s+/ /g;
    $text =~ s/ \z//;

    # Remove any markers we put in the text.
    # Should we remove other non-regular bytes that may come from the source?
    $text =~ s/\0//g;

    return \$text;
}

=head2 pod_lines

ArrayRef of ArrayRefs of offset and length of pod blocks. Example:

 # Two blocks of pod, starting at line 1 and line 15 with length
 # of 10 lines each
 [[1,10], [15,10]]

=cut

has pod_lines => (
    is      => 'ro',
    isa     => ArrayRef,
    type    => 'integer',
    lazy    => 1,
    builder => '_build_pod_lines',
    index   => 'no',
);

sub _build_pod_lines {
    my $self = shift;
    return [] unless ( $self->is_perl_file );
    my ( $lines, $slop ) = MetaCPAN::Util::pod_lines( ${ $self->content } );
    $self->_set_slop( $slop || 0 );
    return $lines;
}

=head2 sloc

Source Lines of Code. Strips empty lines, pod and C<END> section from
L</content> and returns the number of lines.

=cut

has sloc => (
    required => 1,
    is       => 'ro',
    isa      => Int,
    lazy     => 1,
    builder  => '_build_sloc',
);

# Metrics from Perl::Metrics2::Plugin::Core.
sub _build_sloc {
    my $self = shift;
    return 0 unless ( $self->is_perl_file );

    my @content = split( "\n", ${ $self->content } );
    my $pods    = 0;

    # Use pod_lines data to remove pod content from string.
    map {
        splice( @content, $_->[0], $_->[1], map {''} 1 .. $_->[1] )
    } @{ $self->pod_lines };

    my $sloc = 0;
    while (@content) {
        my $line = shift @content;
        last if ( $line =~ /^\s*__(DATA|END)__/s );
        $sloc++ if ( $line !~ /^\s*#/ && $line =~ /\S/ );
    }
    return $sloc;
}

=head2 slop

Source Lines of Pod. Returns the number of pod lines using L</pod_lines>.

=cut

has slop => (
    required => 1,
    is       => 'ro',
    isa      => Int,
    lazy     => 1,
    builder  => '_build_slop',
    writer   => '_set_slop',
);

sub _build_slop {
    my $self = shift;
    return 0 unless ( $self->is_perl_file );
    $self->_build_pod_lines;

    # danger! infinite recursion if not set by `_build_pod_lines`
    # we should probably find a better solution -- Mickey
    return $self->slop;
}

=head2 stat

L<File::stat> info of the archive file. Contains C<mode>,
C<size> and C<mtime>.

=cut

has stat => (
    is      => 'ro',
    isa     => Stat,
    dynamic => 1,
);

=head2 version

Contains the raw version string.

=cut

has version => ( is => 'ro', );

=head2 version_numified

B<Lazy Build>

Numeric representation of L</version>. Contains 0 if there is no version or the
version could not be parsed.

=cut

has version_numified => (
    required => 1,
    is       => 'ro',
    isa      => Num,
    lazy     => 1,
    builder  => '_build_version_numified',
);

sub _build_version_numified {
    my $self = shift;
    return numify_version( $self->version );
}

=head2 mime

MIME type of file. Derived using L<Plack::MIME> (for speed).

=cut

has mime => (
    required => 1,
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_mime',
);

sub _build_mime {
    my $self = shift;
    if (  !$self->directory
        && $self->name !~ /\./
        && grep { $self->name ne $_ } @NOT_PERL_FILES )
    {
        my $content = ${ $self->content };
        return "text/x-script.perl" if ( $content =~ /^#!.*?perl/ );
    }
    else {
        return Plack::MIME->mime_type( $self->name ) || 'text/plain';
    }
}

has [qw(path author name)] => ( is => 'ro', required => 1 );

sub _build_path {
    my $self = shift;
    return join( '/', $self->release->name, $self->name );
}

has dir => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_dir',
    index   => 'not_analyzed'
);

sub _build_dir {
    my $self = shift;
    $DB::single = 1;
    my $dir = $self->path;
    $dir =~ s{/[^/]+$}{};
    return $dir;
}

has [qw(release distribution)] => (
    is       => 'ro',
    required => 1,
    analyzer => [qw(standard camelcase lowercase)],
);

=head1 ATTRIBUTES

These attributes are not stored.

=head2 content

A scalar reference to the content of the file.

=cut

has content => (
    is       => 'ro',
    isa      => ScalarRef,
    lazy     => 1,
    default  => sub { \"" },
    property => 0,
);

=head2 local_path

This attribute holds the path to the file on the local filesystem.

=cut

has local_path => (
    is       => 'ro',
    property => 0,
);

=head2 metadata

Reference to the L<CPAN::Meta> object of the release.

=cut

has metadata => (
    is       => 'ro',
    isa      => 'CPAN::Meta',
    lazy     => 1,
    default  => sub { die 'meta attribute missing' },
    property => 0,
);

=head1 METHODS

=head2 is_perl_file

Return true if the file extension is one of C<pl>, C<pm>, C<pod>, C<t>
or if the file has no extension, is not a binary file and its size is less
than 131072 bytes. This is an arbitrary limit but it keeps the pod parser
happy and the indexer fast.

=cut

sub is_perl_file {
    my $self = shift;
    return 0 if ( $self->directory );
    return 1 if ( $self->name =~ /\.(pl|pm|pod|t)$/i );
    return 1 if ( $self->mime eq "text/x-script.perl" );
    return 1
        if ( $self->name !~ /\./
        && !( grep { $self->name eq $_ } @NOT_PERL_FILES )
        && !$self->binary
        && $self->stat->{size} < 2**17 );
    return 0;
}

=head2 is_pod_file

Returns true if the file extension is C<pod>.

=cut

sub is_pod_file {
    shift->name =~ /\.pod$/i;
}

=head2 add_module

Requires at least one parameter which can be either a HashRef or
an instance of L<MetaCPAN::Document::Module>.

=cut

sub add_module {
    my ( $self, @modules ) = @_;
    $_ = MetaCPAN::Document::Module->new($_)
        for ( grep { ref $_ eq 'HASH' } @modules );
    $self->_set_module( [ @{ $self->module }, @modules ] );
}

=head2 is_in_other_files

Returns true if the file is one from the list below.

=cut

sub is_in_other_files {
    my $self  = shift;
    my @other = qw(
        AUTHORS
        Build.PL
        Changelog
        ChangeLog
        CHANGELOG
        Changes
        CHANGES
        CONTRIBUTING
        CONTRIBUTING.md
        CONTRIBUTING.pod
        Copying
        COPYRIGHT
        cpanfile
        CREDITS
        dist.ini
        FAQ
        INSTALL
        INSTALL.md
        INSTALL.pod
        LICENSE
        Makefile.PL
        MANIFEST
        META.json
        META.yml
        NEWS
        README
        README.md
        README.pod
        THANKS
        Todo
        ToDo
        TODO
    );

    return any { $self->path eq $_ } @other;
}

=head2 set_indexed

Expects a C<$meta> parameter which is an instance of L<CPAN::Meta>.

For each package (L</module>) in the file and based on L<CPAN::Meta/should_index_package>
it is decided, whether the module should have a true L</indexed> attribute.
If there are any packages with leading underscores, the module gets a false
L</indexed> attribute, because PAUSE doesn't allow this kind of name for packages
(https://github.com/andk/pause/blob/master/lib/PAUSE/pmfile.pm#L249).

If L<CPAN::Meta/should_index_package> returns true but the package declaration
uses the I<hide from PAUSE> hack, the L</indexed> property is set to false.

 package # hide from PAUSE
   MyTest::Module;
 # will result in indexed => 0

Once that is done, the L</indexed> property of the file is determined by searching
the list of L<modules|/module> for a module that matches the value of L</documentation>.
If there is no such module, the L</indexed> property is set to false. If the file
does not include any modules, the L</indexed> property is true.

=cut

sub set_indexed {
    my ( $self, $meta ) = @_;

    # modules explicitly listed in 'provides' should be indexed
    foreach my $mod ( @{ $self->module } ) {
        if ( exists $meta->provides->{ $mod->name }
            and $self->path eq $meta->provides->{ $mod->name }{file} )
        {
            $mod->_set_indexed(1);
            return;
        }
    }

    # files listed under 'other files' are not shown in a search
    if ( $self->is_in_other_files() ) {
        foreach my $mod ( @{ $self->module } ) {
            $mod->_set_indexed(0);
        }
        $self->_set_indexed(0);
        return;
    }

    # files under no_index directories should not be indexed
    foreach my $dir ( @{ $meta->no_index->{directory} } ) {
        if ( $self->path eq $dir or $self->path =~ /^$dir\// ) {
            $self->_set_indexed(0);
            return;
        }
    }

    foreach my $mod ( @{ $self->module } ) {
        if ( $mod->name !~ /^[A-Za-z]/
            or !$meta->should_index_package( $mod->name ) )
        {
            $mod->_set_indexed(0);
            next;
        }

        $mod->_set_indexed(
            $mod->hide_from_pause( ${ $self->content }, $self->name )
            ? 0
            : 1
        );
    }

    $self->_set_indexed(

        # .pm file with no package declaration but pod should be indexed
        !@{ $self->module } ||

           # don't index if the documentation doesn't match any of its modules
            !!grep { $self->documentation eq $_->name } @{ $self->module }
    ) if ( $self->documentation );
}

=head2 set_authorized

Expects a C<$perms> parameter which is a HashRef. The key is the module name
and the value an ArrayRef of author names who are allowed to release
that module.

The method returns a list of unauthorized, but indexed modules.

Unauthorized modules are modules that were uploaded in the name of a
different author than stated in the C<06perms.txt.gz> file. One problem
with this file is, that it doesn't record historical data. It may very
well be that an author was authorized to upload a module at the time.
But then his co-maintainer rights might have been revoked, making consecutive
uploads of that release unauthorized. However, since this script runs
with the latest version of C<06perms.txt.gz>, the former upload will
be flagged as unauthorized as well. Same holds the other way round,
a previously unauthorized release would be flagged authorized if the
co-maintainership was added later on.

If a release contains unauthorized modules, the whole release is marked
as unauthorized as well.

=cut

sub set_authorized {
    my ( $self, $perms ) = @_;

    # only authorized perl distributions make it into the CPAN
    return () if ( $self->distribution eq 'perl' );
    foreach my $module ( @{ $self->module } ) {
        $module->_set_authorized(0)
            if ( $perms->{ $module->name } && !grep { $_ eq $self->author }
            @{ $perms->{ $module->name } } );
    }
    $self->_set_authorized(0)
        if ( $self->authorized
        && $self->documentation
        && $perms->{ $self->documentation }
        && !grep { $_ eq $self->author }
        @{ $perms->{ $self->documentation } } );
    return grep { !$_->authorized && $_->indexed } @{ $self->module };
}

=head2 full_path

Concatenate L</author>, L</release> and L</path>.

=cut

sub full_path {
    my $self = shift;
    return join( '/', $self->author, $self->release, $self->path );
}

__PACKAGE__->meta->make_immutable;
1;
