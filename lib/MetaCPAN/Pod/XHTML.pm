package MetaCPAN::Pod::XHTML;

=head2 SYNOPSIS

We need to mess with the POD links a bit so that everything will work with
relative rather than absolute URLs.

=cut

use Moose;

extends 'Pod::Simple::XHTML';

use Modern::Perl;
use Data::Dump qw( dump );
use HTML::Entities;
use IO::File;
use Path::Class::File;

sub start_L {
    my ( $self, $flags ) = @_;
    my ( $type, $to, $section ) = @{$flags}{ 'type', 'to', 'section' };
    
    #print "$type $to $section\n" if $section;
        
    my $url
        = $type eq 'url' ? $to
        : $type eq 'pod' ? $self->resolve_pod_page_link( $to, $section )
        : $type eq 'man' ? $self->resolve_man_page_link( $to, $section )
        :                  undef;
    
    my $class = ( $type eq 'pod' ) ? ' class="moduleLink"' : '';
        
    $self->{'scratch'} .= qq[<a href="$url"$class>];
}

sub start_Verbatim {

}

sub end_Verbatim {

    $_[0]{'scratch'} = '<pre>' . $_[0]{'scratch'} . '</pre>';
    $_[0]->emit;
    
}

1;
