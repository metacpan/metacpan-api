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
the release L</name>. See L</ElasticSearchX::Model::Util::digest>.

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

If the file L</is_pod_file|is a pod file, the name is derived from the
C<NAME> section. If the file L</is_perl_file|is a perl file> and the
name from the C<NAME> section matches on of the modules in L</module>,
it returns the name. Otherwise it returns the name of the first module
in L</module>. If there are no modules in the file the documentation is
set to C<undef>.

=head2 indexed

B<Default 0>

Indicates whether the file should be included in the search index or
not. If the L</documentation> refers to an unindexed module in
L</module>, the file is considered unindexed.

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

Numified version of L</version>. Contains 0 if there is no version or the
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
    clearer         => 'clear_module'
);
has documentation => (
    required   => 1,
    is         => 'rw',
    lazy_build => 1,
    index      => 'analyzed',
    predicate  => 'has_documentation',
    analyzer   => [qw(standard camelcase lowercase)]
);

has date => ( is => 'ro', required => 1, isa => 'DateTime' );
has stat => ( is => 'ro', isa => Stat, required => 0, dynamic => 1 );
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
has authorized => ( required => 1, is => 'ro', isa => 'Bool', default => 1 );
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

Callback, that returns the content of the as ScalarRef.

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

=head1 METHODS

=head2 is_perl_file

Return true if the file extension is one of C<pl>, C<pm>, C<pod>, C<t>
or if the file has no extension and the shebang line contains the
term C<perl>.

=head2 is_pod_file

Retruns true if the file extension is C<pod>.

=cut

sub is_perl_file {
    my $self = shift;
    return 0 if ( $self->directory );
    return 1 if ( $self->name =~ /\.(pl|pm|pod|t)$/i );
    return 1 if ( $self->mime eq "text/x-script.perl" );
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
    if ( !$self->directory && $self->name !~ /\./ ) {
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

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::File::Set;
use Moose;
extends 'ElasticSearchX::Model::Document::Set';

sub find {
    my ( $self, $module ) = @_;
    return $self->filter(
        {   and => [
                { term => { 'documentation' => $module } },
                { term => { 'file.indexed'  => \1, } },
                { term => { status          => 'latest', } },
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
        )->first;
}

__PACKAGE__->meta->make_immutable;
