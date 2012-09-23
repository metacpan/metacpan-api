package MetaCPAN::Document::File;
use Moose;
use ElasticSearchX::Model::Document;

use URI::Escape ();
use MetaCPAN::Pod::XHTML;
use Pod::Text;
use Plack::MIME;
use List::MoreUtils qw(uniq);
use MetaCPAN::Util;
use MetaCPAN::Types qw(:all);
use MooseX::Types::Moose qw(ArrayRef);
use Encode;
use utf8;

Plack::MIME->add_type( ".t"   => "text/x-script.perl" );
Plack::MIME->add_type( ".pod" => "text/x-pod" );
Plack::MIME->add_type( ".xs"  => "text/x-c" );

=head1 PROPERTIES

=head2 abstract

Abstract of the documentation (if any). This is built by parsing the
C<NAME> section. It also sets L</documentation> if it succeeds.

=head2 id

Unique identifier of the release. Consists of the L</author>'s pauseid and
the release L</name>. See L<ElasticSearchX::Model::Util/digest>.

=head2 module

An ArrayRef of L<MetaCPAN::Document::Module> objects, that represent
modules defined in that class (i.e. package declarations).

=head2 date

B<Required>

Release date (i.e. C<mtime> of the tarball).

=head2 description

Contains the C<DESCRIPTION> section of the POD if any. Will be stripped from
whitespaces and POD commands.

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

=head2 maturity

Maturity of the release. This can either be C<released> or C<developer>.
See L<CPAN::DistnameInfo>.

=head2 directory

Return true if this object represents a directory.

=head2 documentation

Holds the name for the documentation in this file.

If the file L</is_pod_file|is a pod file>, the name is derived from the
C<NAME> section. If the file L</is_perl_file|is a perl file> and the
name from the C<NAME> section matches one of the modules in L</module>,
it returns the name. Otherwise it returns the name of the first module
in L</module>. If there are no modules in the file the documentation is
set to C<undef>.

=head2 indexed

B<Default 0>

Indicates whether the file should be included in the search index or
not. See L</set_indexed> for a more verbose explanation.

=head2 level

Level of this file in the directory tree of the release (i.e. C<META.yml>
has a level of C<0>).

=head2 pod

Pure text format of the pod (see L</Pod::Text>). Consecutive whitespaces
are removed to save space and for better snippet previews.

=head2 pod_lines

ArrayRef of ArrayRefs of offset and length of pod blocks. Example:

 # Two blocks of pod, starting at line 1 and line 15 with length
 # of 10 lines each
 [[1,10], [15,10]]

=head2 sloc

Source Lines of Code. Strips empty lines, pod and C<END> section from
L</content> and returns the number of lines.

=head2 slop

Source Lines of Pod. Returns the number of pod lines using L</pod_lines>.

=head2 stat

L<File::stat> info of the tarball. Contains C<mode>, C<uid>, C<gid>, C<size>
and C<mtime>.

=head2 version

Contains the raw version string.

=head2 version_numified

B<Required>, B<Lazy Build>

Numeric representation of L</version>. Contains 0 if there is no version or the
version could not be parsed.

=cut

has id => ( is => 'ro', id => [qw(author release path)] );

has [qw(path author name)] => ( is => 'ro', required => 1 );
has [qw(release distribution)] => (
    is       => 'ro',
    required => 1,
    analyzer => [qw(standard camelcase lowercase)],
);
has module => (
    required        => 0,
    is              => 'rw',
    isa             => Module,
    type            => 'nested',
    include_in_root => 1,
    coerce          => 1,
    clearer         => 'clear_module',
    lazy            => 1,
    default         => sub { [] },
);
has documentation => (
    required   => 1,
    is         => 'rw',
    lazy_build => 1,
    index      => 'analyzed',
    predicate  => 'has_documentation',
    analyzer   => [qw(standard camelcase lowercase)],
    clearer    => 'clear_documentation',
);
has date => ( is => 'ro', required => 1, isa => 'DateTime' );
has stat => ( is => 'ro', isa => Stat, required => 0, dynamic => 1 );
has binary => ( is => 'ro', isa => 'Bool', required => 1, default => 0 );
has sloc => ( is => 'ro', required => 1, isa => 'Int', lazy_build => 1 );
has slop =>
    ( is => 'ro', required => 1, isa => 'Int', is => 'rw', lazy_build => 1 );
has pod_lines => (
    is         => 'ro',
    required   => 1,
    isa        => 'ArrayRef',
    type       => 'integer',
    lazy_build => 1,
    index      => 'no'
);

has pod => (
    is           => 'ro',
    required     => 1,
    isa          => 'ScalarRef',
    lazy_build   => 1,
    index        => 'analyzed',
    not_analyzed => 0,
    store        => 'no',
    term_vector  => 'with_positions_offsets'
);

has mime => ( is => 'ro', required => 1, lazy_build => 1 );
has abstract =>
    ( is => 'ro', required => 1, lazy_build => 1, index => 'analyzed' );
has description =>
    ( is => 'ro', required => 1, lazy_build => 1, index => 'analyzed' );
has status => ( is => 'ro', required => 1, default => 'cpan' );
has authorized => ( required => 1, is => 'rw', isa => 'Bool', default => 1 );
has maturity => ( is => 'ro', required => 1, default => 'released' );
has directory => ( is => 'ro', required => 1, isa => 'Bool', default => 0 );
has level => ( is => 'ro', required => 1, isa => 'Int', lazy_build => 1 );
has indexed => ( required => 1, is => 'rw', isa => 'Bool', default => 1 );
has version => ( is => 'ro', required => 0 );
has version_numified =>
    ( is => 'ro', isa => 'Num', lazy_build => 1, required => 1 );

sub _build_version_numified {
    my $self = shift;
    return 0 unless ( $self->version );
    return MetaCPAN::Util::numify_version( $self->version );
}

=head1 ATTRIBUTES

These attributes are not stored.

=head2 content

The content of the file. It is built by calling L</content_cb> and
stripping the C<DATA> section for performance reasons.

=head2 content_cb

Callback that returns the content of the file as a ScalarRef.

=cut

has content => (
    is         => 'ro',
    isa        => 'ScalarRef',
    lazy_build => 1,
    property   => 0,
    required   => 0
);
has content_cb => (
    is       => 'ro',
    property => 0,
    required => 0,
    default  => sub {
        sub { \'' }
    }
);

=head2 local_path

This attribute holds the path to the file on the local filesystem.

=cut

has local_path => (
    is       => 'ro',
    property => 0,
);

=head1 METHODS

=head2 is_perl_file

Return true if the file extension is one of C<pl>, C<pm>, C<pod>, C<t>
or if the file has no extension, is not a binary file and its size is less
than 131072 bytes. This is an arbitrary limit but it keeps the pod parser
happy and the indexer fast.

=head2 is_pod_file

Retruns true if the file extension is C<pod>.

=cut

my @NOT_PERL_FILES = qw(SIGNATURE);

sub is_perl_file {
    my $self = shift;
    return 0 if ( $self->directory );
    return 1 if ( $self->name =~ /\.(pl|pm|pod|t)$/i );
    return 1 if ( $self->mime eq "text/x-script.perl" );
    return 1
        if ( $self->name !~ /\./
        && !grep { $self->name eq $_ } @NOT_PERL_FILES
        && !$self->binary
        && $self->stat->{size} < 2**17 );
    return 0;
}

sub is_pod_file {
    shift->name =~ /\.pod$/i;
}

sub _build_documentation {
    my $self = shift;
    $self->_build_abstract;
    my $documentation = $self->documentation if ( $self->has_documentation );
    return undef unless ( ${ $self->pod } );
    my @indexed = grep { $_->indexed } @{ $self->module || [] };
    if ( $documentation && $self->is_pod_file ) {
        return $documentation;
    }
    elsif ( $documentation && grep { $_->name eq $documentation } @indexed ) {
        return $documentation;
    }
    elsif (@indexed) {
        return $indexed[0]->name;
    }
    elsif ( !@{ $self->module || [] } ) {
        return $documentation;
    }
    else {
        return undef;
    }
}

sub _build_level {
    my $self = shift;
    my @level = split( /\//, $self->path );
    return @level - 1;
}

sub _build_content {
    my $self    = shift;
    my @content = split( "\n", ${ $self->content_cb->() } || '' );
    my $content = "";
    my $in_data = 0;    # skip DATA section
    while (@content) {
        my $line = shift @content;
        if ( $line =~ /^\s*__END__\s*$/ ) {
            $in_data = 0;
        }
        elsif ( $line =~ /^\s*__DATA__\s*$/ ) {
            $in_data++;
        }
        elsif ( $in_data && $line =~ /^=head1/ ) {
            $in_data = 0;
        }
        next if ($in_data);
        $content .= $line . "\n";
    }
    return \$content;
}

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

sub _build_description {
    my $self = shift;
    return undef unless ( $self->is_perl_file );
    my $section = MetaCPAN::Util::extract_section( ${ $self->content },
        'DESCRIPTION' );
    return undef unless ($section);
    my $parser = Pod::Text->new;
    my $text   = "";
    $parser->output_string( \$text );
    $parser->parse_string_document("=pod\n\n$section");
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

sub _build_abstract {
    my $self = shift;
    return undef unless ( $self->is_perl_file );
    my $text = ${ $self->content };
    my ( $documentation, $abstract );
    my $section = MetaCPAN::Util::extract_section( $text, 'NAME' );
    return undef unless ($section);
    $section =~ s/^=\w+.*$//mg;
    $section =~ s/X<.*?>//mg;
    if ( $section =~ /^\s*(\S+)((\h+-+\h+(.+))|(\r?\n\h*\r?\n\h*(.+)))?/ms ) {
        chomp( $abstract = $4 || $6 ) if ( $4 || $6 );
        my $name = MetaCPAN::Util::strip_pod($1);
        $documentation = $name if ( $name =~ /^[\w\.:\-_']+$/ );
    }
    if ($abstract) {
        $abstract =~ s/^=\w+.*$//xms;
        $abstract =~ s{\r?\n\h*\r?\n\h*.*$}{}xms;
        $abstract =~ s{\n}{ }gxms;
        $abstract =~ s{\s+$}{}gxms;
        $abstract =~ s{(\s)+}{$1}gxms;
        $abstract = MetaCPAN::Util::strip_pod($abstract);
    }

    if ($documentation) {
        $self->documentation( MetaCPAN::Util::strip_pod($documentation) );
    }
    return $abstract;

}

sub _build_path {
    my $self = shift;
    return join( '/', $self->release->name, $self->name );
}

sub _build_pod_lines {
    my $self = shift;
    return [] unless ( $self->is_perl_file );
    my ( $lines, $slop ) = MetaCPAN::Util::pod_lines( ${ $self->content } );
    $self->slop( $slop || 0 );
    return $lines;
}

sub _build_slop {
    my $self = shift;
    return 0 unless ( $self->is_perl_file );
    $self->_build_pod_lines;
    return $self->slop;
}

# Copied from Perl::Metrics2::Plugin::Core
sub _build_sloc {
    my $self = shift;
    return 0 unless ( $self->is_perl_file );
    my @content = split( "\n", ${ $self->content } );
    my $pods = 0;
    map {
        splice( @content, $_->[0], $_->[1], map {''} 1 .. $_->[1] )
    } @{ $self->pod_lines };
    my $sloc = 0;
    while (@content) {
        my $line = shift @content;
        last if ( $line =~ /^\s*__END__/s );
        $sloc++ if ( $line !~ /^\s*#/ && $line =~ /\S/ );
    }
    return $sloc;
}

sub _build_pod {
    my $self = shift;
    return \'' unless ( $self->is_perl_file );
    my $parser = Pod::Text->new( sentence => 0, width => 78 );

    my $text = "";
    $parser->output_string( \$text );
    $parser->parse_string_document( ${ $self->content } );
    $text =~ s/\s+/ /g;
    return \$text;
}

=head2 add_module

Requires at least one parameter which can be either a HashRef or
an instance of L<MetaCPAN::Document::Module>.

=cut

sub add_module {
    my ( $self, @modules ) = @_;
    $_ = MetaCPAN::Document::Module->new($_)
        for ( grep { ref $_ eq 'HASH' } @modules );
    $self->module( [ @{ $self->module }, @modules ] );
}

=head2 set_indexed

Expects a C<$meta> parameter which is an instance of L<CPAN::Meta>.

For each package (L</module>) in the file and based on L<CPAN::Meta/should_index_package>
it is decided, whether the module should have a true L</indexed> attribute.
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
    foreach my $mod ( @{ $self->module } ) {
        $mod->indexed(
              $meta->should_index_package( $mod->name )
            ? $mod->hide_from_pause( ${ $self->content } )
                    ? 0
                    : 1
            : 0
        ) unless ( $mod->indexed );
    }
    $self->indexed(

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
        $module->authorized(0)
            if ( $perms->{ $module->name } && !grep { $_ eq $self->author }
            @{ $perms->{ $module->name } } );
    }
    $self->authorized(0)
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
    return join("/", $self->author, $self->release, $self->path);
}

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::File::Set;
use Moose;
extends 'ElasticSearchX::Model::Document::Set';

my @ROGUE_DISTRIBUTIONS
    = qw(kurila perl_debug perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx Bundle-Everything);

sub find {
    my ( $self, $module ) = @_;
    my @candidates = $self->filter(
        {   and => [
                {   or => [
                        { term => { 'file.module.name'   => $module } },
                        { term => { 'file.documentation' => $module } },
                    ]
                },
                { term => { 'file.indexed' => \1, } },
                { term => { status         => 'latest', } },
                {   not =>
                        { filter => { term => { 'file.authorized' => \0 } } }
                },
            ]
        }
        )->sort(
        [   { 'date' => { order => "desc" } },
            'mime',
            { 'stat.mtime' => { order => 'desc' } }
        ]
        )->size(100)->all;

    my ($file) = grep {
        grep { $_->indexed && $_->authorized && $_->name eq $module }
            @{ $_->module || [] }
    } grep { !$_->documentation || $_->documentation eq $module } @candidates;

    # REINDEX: after a full reindex, the rest of the sub can be replaced with
    # return $file ? $file : shift @candidates;
    return shift @candidates unless ($file);

    ($module) = grep { $_->name eq $module } @{ $file->module };
    return $file if ( $module->associated_pod );

    # if there is a .pod file in the same release, we use that instead
    if (my ($pod) = grep {
                   $_->release eq $file->release
                && $_->author  eq $file->author
                && $_->is_pod_file
        } @candidates
        )
    {
        $module->associated_pod(
            join( "/", map { $pod->$_ } qw(author release path) ) );
    }
    return $file;
}

sub find_pod {
    my ( $self, $name ) = @_;
    my $file = $self->find($name);
    return $file unless($file);
    my ($module) = grep { $_->indexed && $_->authorized && $_->name eq $name }
            @{ $file->module || [] };
    if($module && (my $pod = $module->associated_pod)) {
        my ($author, $release, @path) = split(/\//, $pod);
        return $self->get({
            author => $author,
            release => $release,
            path => join("/", @path),
        });
    } else {
        return $file;
    }
}

# return files that contain modules that match the given dist
# NOTE: these still need to be filtered by authorized/indexed
# TODO: test that we are getting the correct version (latest)
sub find_provided_by {
    my ( $self, $release ) = @_;
    return $self->filter(
        {   and => [
                { term => { 'release' => $release->{name} } },
                { term => { 'author'  => $release->{author} } },
                { term => { 'file.module.authorized' => 1 } },
                { term => { 'file.module.indexed'    => 1 } },
            ]
        }
    )->size(999)->all;
}

# filter find_provided_by results for indexed/authorized modules
# and return a list of package names
sub find_module_names_provided_by {
    my ( $self, $release ) = @_;
    my $mods = $self->inflate(0)->find_provided_by($release);
    return (
        map { $_->{name} }
        grep { $_->{indexed} && $_->{authorized} }
        map { @{ $_->{_source}->{module} } } @{ $mods->{hits}->{hits} }
    );
}

sub prefix {
    my ( $self, $prefix ) = @_;
    my @query = split( /\s+/, $prefix );
    my $should = [
        map {
            { field     => { 'documentation.analyzed'  => "$_*" } },
                { field => { 'documentation.camelcase' => "$_*" } }
            } grep {$_} @query
    ];
    return $self->query(
        {   filtered => {
                query => {
                    custom_score => {
                        query => { bool => { should => $should } },
                        script =>
                            "_score - doc['documentation'].stringValue.length()/100"
                    },
                },
                filter => {
                    and => [
                        {   not => {
                                filter => {
                                    or => [
                                        map {
                                            +{  term => {
                                                    'file.distribution' => $_
                                                }
                                                }
                                            } @ROGUE_DISTRIBUTIONS

                                    ]
                                }
                            }
                        },
                        { exists => { field          => 'documentation' } },
                        { term   => { 'file.indexed' => \1 } },
                        { term   => { 'file.status'  => 'latest' } },
                        {   not => {
                                filter =>
                                    { term => { 'file.authorized' => \0 } }
                            }
                        }
                    ]
                }
            }
        }
    );
}

__PACKAGE__->meta->make_immutable;
