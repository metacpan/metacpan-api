package MetaCPAN::Document::File;
use Moose;
use ElasticSearchX::Model::Document;

use URI::Escape ();
use Pod::Tree;
use MetaCPAN::Pod::XHTML;
use Pod::Text;
use Plack::MIME;
use List::MoreUtils qw(uniq);
use MetaCPAN::Util;
use MetaCPAN::Types qw(:all);
use MooseX::Types::Moose qw(ArrayRef);

Plack::MIME->add_type( ".t"   => "text/x-script.perl" );
Plack::MIME->add_type( ".pod" => "text/x-script.perl" );
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

Pure text format of the pod (see L</Pod::Text>.

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

=cut

has id => ( id => [qw(author release path)] );

has [qw(path author name)];
has distribution => ( analyzer => [qw(standard camelcase)] );
has module => ( required => 0, is => 'rw', isa => Module, coerce => 1, clearer => 'clear_module' );
has documentation => ( is => 'rw', lazy_build => 1, index => 'analyzed', analyzer => [qw(standard camelcase)] );
has release => ( parent => 1 );
has date => ( isa => 'DateTime' );
has stat => ( isa => Stat, required => 0 );
has sloc => ( isa => 'Int',        lazy_build => 1 );
has slop => ( isa => 'Int', is => 'rw', default => 0 );
has pod_lines => ( isa => 'ArrayRef', type => 'integer', lazy_build => 1, index => 'no' );
has pod  => ( isa => 'ScalarRef', lazy_build => 1, index => 'analyzed', not_analyzed => 0, store => 'no', term_vector => 'with_positions_offsets' );
has mime => ( lazy_build => 1 );
has abstract => ( lazy_build => 1, not_analyzed => 0, index => 'analyzed' );
has status => ( default => 'cpan' );
has maturity => ( default => 'released' );
has directory => ( isa => 'Bool', default => 0 );
has level => ( isa => 'Int', lazy_build => 1 );
has indexed => ( is => 'rw', isa => 'Bool', default => 1 );

=head1 ATTRIBUTES

These attributes are not stored.

=head2 content

The content of the file. It is built by calling L</content_cb> and
stripping the C<DATA> section for performance reasons.

=head2 content_cb

Callback, that returns the content of the as ScalarRef.

=head2 pom

L<Pod::Tree> object if the file is a perl file (L</is_perl_file>).

=cut

has content => ( isa => 'ScalarRef', lazy_build => 1, property => 0, required => 0 );
has pom => ( lazy_build => 1, property => 0, required => 0 );
has content_cb => ( property => 0, required => 0 );

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
    return 1 if($self->name =~ /\.(pl|pm|pod|t)$/i);
    if($self->name !~ /\./) {
        my $content = ${$self->content};
        return 1 if($content =~ /^#!.*?perl/);
    }
    return 0;
}

sub is_pod_file {
    shift->name =~ /\.pod$/i;
}

sub _build_documentation {
    my $self = shift;
    $self->_build_abstract;
    my $documentation = $self->documentation if($self->has_documentation);
    return undef unless(${$self->pod});
    my @indexed = grep { $_->indexed } @{$self->module || []};
    if($documentation && $self->is_pod_file) {
        return $documentation;
    } elsif($documentation && grep {$_->name eq $documentation} @indexed) {
        return $documentation;
    } elsif(@indexed) {
        return $indexed[0]->name;
    } else {
        return undef;
    }
}

sub _build_level {
    my $self = shift;
    my @level = split(/\//, $self->path);
    return @level - 1;
}

sub _build_content {
    my $self = shift;
    my @content = split("\n", ${$self->content_cb->()} || '');
    my $content = "";
    while(@content) {
        my $line = shift @content;
        last if($line =~ /^\s*__DATA__$/);
        $content .= $line . "\n";
    }
    return \$content;
}

sub _build_mime {
    Plack::MIME->mime_type( shift->name ) || 'text/plain';
}

sub _build_pom {
    my $self = shift;
    return undef unless($self->is_perl_file);
    my $pod = Pod::Tree->new;
    $pod->load_string( ${ $self->content } );
    return $pod;
}

sub _build_abstract {
    my $self = shift;
    return undef unless ( $self->is_perl_file );
    my $root    = $self->pom->get_root;
    my $in_name = 0;
    my ( $abstract, $documentation );
    foreach my $node ( @{ $root->get_children } ) {
        if ($in_name) {
            last
              if (    $node->get_type eq 'command'
                   && $node->get_command eq 'head1' );

            my $text = MetaCPAN::Util::strip_pod($node->get_text);
            # warn $text;
            if ( $in_name == 1 && $text =~ /^\h*(\S+?)(\h+-+\h+(.*))?$/s ) {
                chomp($abstract = $3);
                my $name = $1;
                $documentation = $name if($name =~ /^[\w\.:']+$/);
            } elsif ( $in_name == 1 && $text =~ /^\h*([\w\:']+?)\n/s ) {
                chomp($documentation = $1);
            } elsif( $in_name == 2 && !$abstract && $text) {
                chomp($abstract = $text);
            }

            if ($abstract) {
                $abstract =~ s{=head.*}{}xms;
                $abstract =~ s{\n\n.*$}{}xms;
                $abstract =~ s{\n}{ }gxms;
                $abstract =~ s{\s+$}{}gxms;
                $abstract =~ s{(\s)+}{$1}gxms;
            }
            $in_name++;
        }

        last if ( $abstract && $documentation );

        $in_name++
          if (    $node->get_type eq 'command'
               && $node->get_command eq 'head1'
               && $node->get_text =~ /^NAME\s*$/ );

    }
    $self->documentation($documentation) if ($documentation);
    return $abstract;

}

sub _build_path {
    my $self = shift;
    return join( '/', $self->release->name, $self->name );
}

sub _build_pod_lines {
    my $self = shift;
    return [] unless ( $self->is_perl_file );
    my ($lines, $slop) = MetaCPAN::Util::pod_lines(${$self->content});
    $self->slop($slop || 0);
    return $lines;
    
}

# Copied from Perl::Metrics2::Plugin::Core
sub _build_sloc {
    my $self = shift;
    return 0 unless ( $self->is_perl_file );
    my @content = split("\n", ${$self->content});
    my $pods = 0;
    map { splice(@content, $_->[0], $_->[1], map { '' } 1 .. $_->[1]) } @{$self->pod_lines};
    my $sloc = 0;
    while(@content) {
        my $line = shift @content;
        last if($line =~ /^\s*__END__/s);
        $sloc++ if( $line !~ /^\s*#/ && $line =~ /\S/ );
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

    return \$text;
}

__PACKAGE__->meta->make_immutable;
