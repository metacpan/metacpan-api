package MetaCPAN::Document::File;
use Moose;
use ElasticSearchX::Model::Document;

use URI::Escape ();
use Pod::Tree;
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
has module => ( required => 0, is => 'rw', isa => Module, coerce => 1 );
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
has level => ( isa => 'Int', lazy_build => 1 );


has content => ( isa => 'ScalarRef', lazy_build => 1, property   => 0, required => 0 );
has ppi     => ( isa => 'PPI::Document', lazy_build => 1, property => 0 );
has pom => ( lazy_build => 1, property => 0, required => 0 );
has content_cb => ( property => 0, required => 0 );

sub is_perl_file {
    my $self = shift;
    return 1 if($self->name =~ /\.(pl|pm|pod|t)$/i);
    if($self->name !~ /\./) {
        my $content = ${$self->content};
        return 1 if($content =~ /^#!.*?perl/);
    }
    return 0;
}

sub _build_documentation {
    my $self = shift;
    $self->_build_abstract;
    return $self->documentation if($self->has_documentation);
    return $self->module ? $self->module->[0]->{name} : undef;
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

            my $text = $node->get_text;
            if ( $in_name == 1 && $text =~ /^\h*(.*?)(\h+-\h+(.*))?$/s ) {
                $abstract      = $3;
                chomp($documentation = $1);
            } elsif( $in_name == 2) {
                chomp($abstract = $text);
            }

            if ($abstract) {
                $abstract =~ s{=head.*}{}xms;
                $abstract =~ s{\n\n.*$}{}xms;
                $abstract =~ s{\n}{ }gxms;
                $abstract =~ s{\s+$}{}gxms;
                $abstract =~ s{(\s)+}{$1}gxms;
                $abstract = MetaCPAN::Util::strip_pod($abstract);
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
