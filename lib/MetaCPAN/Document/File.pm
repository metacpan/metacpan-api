package MetaCPAN::Document::File;
use Moose;
use ElasticSearchX::Model::Document;

use URI::Escape ();
use Pod::POM;
use Pod::POM::View::TOC;
use MetaCPAN::Pod::XHTML;
use Pod::Text;
use Plack::MIME;
use List::MoreUtils qw(uniq);
use MetaCPAN::Pod::Lines;
use MetaCPAN::Types qw(:all);
use MooseX::Types::Moose qw(ArrayRef);

Plack::MIME->add_type( ".t"   => "text/x-script.perl" );
Plack::MIME->add_type( ".pod" => "text/x-script.perl" );
Plack::MIME->add_type( ".xs"  => "text/x-c" );

has id => ( id => [qw(author release path)] );

has [qw(path author name distribution)] => ();
has module => ( required => 0, is => 'ro', isa => Module, coerce => 1 );
has documentation => ( required => 1, is => 'rw', lazy_build => 1, index => 'analyzed' );
has release => ( parent => 1 );
has date => ( isa => 'DateTime' );
has stat => ( isa => Stat, required => 0 );
has sloc => ( isa => 'Int',        lazy_build => 1 );
has slop => ( isa => 'Int', is => 'rw', default => 0 );
has pod_lines => ( isa => 'ArrayRef', type => 'integer', lazy_build => 1, index => 'no' );
has pod  => ( isa => 'ScalarRef', lazy_build => 1, index => 'analyzed', store => 'no', term_vector => 'with_positions_offsets' );
has [qw(mime)] => ( lazy_build => 1 );
has abstract => ( lazy_build => 1, index => 'analyzed' );
has status => ( default => 'cpan' );
has maturity => ( default => 'released' );
has directory => ( isa => 'Bool', default => 0 );
has indexed => ( isa => 'Bool', lazy_build => 1 );
has level => ( isa => 'Int', lazy_build => 1 );


has content => ( isa => 'ScalarRef', lazy_build => 1, property   => 0, required => 0 );
has ppi     => ( isa => 'PPI::Document', lazy_build => 1, property => 0 );
has pom => ( lazy_build => 1, property => 0, required => 0 );
has content_cb => ( property => 0, required => 0 );

sub is_perl_file {
    $_[0]->name =~ /\.(pl|pm|pod|t)$/i;
}

sub _build_documentation {
    my $self = shift;
    return unless($self->name =~ /\.(pm|pod)$/i);
    my $pom = $self->pom;
    foreach my $s ( @{ $pom->head1 } ) {
        if ( $s->title eq 'NAME' ) {
            return '' unless ( $s->content =~ /^\s*(.*?)(\s*-\s*(.*))?$/s );
            return $1;
        }
    }
    return undef;
}

sub _build_indexed {
    my $self = shift;
    return 1 unless(my $pkg = $self->module);
    $pkg = $pkg->[0]->{name} || return 0;;
    my $content = ${$self->content};
    return $content =~ /    # match a package declaration
      ^[\h\{;]*             # intro chars on a line
      package               # the word 'package'
      \h+                   # whitespace
      ($pkg)                # a package name
      \h*                   # optional whitespace
      (.+)?                 # optional version number
      \h*                   # optional whitesapce
      ;                     # semicolon line terminator
    /mx ? 1 : 0;
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
    Pod::POM->new( warn => 0 )->parse_text( ${ $self->content } );
}

sub _build_abstract {
    my $self = shift;
    return '' unless ( $self->is_perl_file );
    my $pom = $self->pom;
    foreach my $s ( @{ $pom->head1 } ) {
        if ( $s->title eq 'NAME' ) {
            return '' unless ( $s->content =~ /^\s*(.*?)\s*-\s*(.*)$/s );
            my $content = $2;
            $self->documentation($1);

            # MOBY::Config has more than one POD section in the abstract after
            # parsing Should have a closer look and file bug with Pod::POM
            # It also contains newlines in the actual source
            $content =~ s{=head.*}{}xms;
            $content =~ s{\n\n.*$}{}xms;
            $content =~ s{\n}{ }gxms;
            $content =~ s{\s+$}{}gxms;
            $content =~ s{(\s)+}{$1}gxms;
            $content =~ s{\w<(.*?)>}{$1}gxms;
            return $content || '';
        }
    }
    return '';
}

sub _build_path {
    my $self = shift;
    return join( '/', $self->release->name, $self->name );
}

sub _build_pod_lines {
    my $self = shift;
    return [] unless ( $self->is_perl_file );
    my ($lines, $slop) = MetaCPAN::Pod::Lines::parse(${$self->content});
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
