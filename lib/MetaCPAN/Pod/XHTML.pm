package MetaCPAN::Pod::XHTML;

use strict;
use warnings;

# Keep the coding style of Pod::Simple for consistency and performance.
# Pod::Simple::XHTML expects you to subclass and then override methods.

use parent 'Pod::Simple::XHTML';
use HTML::Entities qw(decode_entities);

__PACKAGE__->_accessorize('link_mappings');

sub resolve_pod_page_link {
    my ( $self, $module, $section ) = @_;
    return undef
        unless defined $module || defined $section;
    $section = defined $section ? '#' . $self->idify( $section, 1 ) : '';
    return $section
        unless defined $module;
    my $link_map = $self->link_mappings || {};
    if ( defined( my $link = $link_map->{$module} ) ) {
        $module = $link;
    }
    my ( $prefix, $postfix ) = map +( defined $_ ? $_ : '' ),
        $self->perldoc_url_prefix, $self->perldoc_url_postfix;
    return $prefix . $module . $postfix . $section;
}

sub _end_head {
    my $self      = shift;
    my $head_name = $self->{htext};
    $self->{more_ids} = [ $self->id_extras($head_name) ];
    $self->SUPER::_end_head(@_);
    my $index_entry = $self->{'to_index'}[-1];
    $index_entry->[1] = $self->encode_entities(
        $self->url_encode( decode_entities( $index_entry->[1] ) ) );
    return;
}

sub end_item_text {
    my $self = shift;
    if ( $self->{anchor_items} ) {
        my $item_name = $self->{'scratch'};
        $self->{more_ids} = [ $self->id_extras($item_name) ];
    }
    $self->SUPER::end_item_text(@_);
}

sub emit {
    my $self = shift;
    my $ids  = delete $self->{more_ids};
    if ( $ids && @$ids ) {
        my $scratch = $self->{scratch};
        my $add = join '', map qq{<a id="$_"></a>}, @$ids;
        $scratch =~ s/(<\w[^>]*>)/$1$add/;
        $self->{scratch} = $scratch;
    }
    $self->SUPER::emit(@_);
}

my %encode = map +( chr($_) => sprintf( '%%%02X', $_ ) ), 0 .. 255;

sub url_encode {
    my ( undef, $t ) = @_;
    utf8::encode($t);
    $t =~ s{([^a-zA-Z0-9-._~!\$&'()*+,;=:@/?])}{$encode{$1}}g;
    $t;
}

sub idify {
    my ( $self, $t, $for_link ) = @_;

    $t =~ s/<[^>]+>//g;
    $t = decode_entities($t);
    $t =~ s/^\s+//;
    $t =~ s/\s+$//;
    $t =~ s/[\s-]+/-/g;

    return $self->url_encode($t)
        if $for_link;

    my $ids = $self->{ids};
    my $i   = '';
    $i++ while $ids->{"$t$i"}++;
    $self->encode_entities("$t$i");
}

sub id_extras {
    my ( $self, $t ) = @_;

    $t =~ s/<[^>]+>//g;
    $t = decode_entities($t);
    $t =~ s/^\s+//;
    $t =~ s/\s+$//;
    $t =~ s/[\s-]+/-/g;

    # $full will be our preferred linking style, without much filtering
    # $first will be the first word, often a method/function name
    # $old will be a heavily filtered form for backwards compatibility

    my $full = $t;
    my ($first) = $t =~ /^(\w+)/;
    $t =~ s/^[^a-zA-Z]+//;
    $t =~ s/^$/pod/;
    $t =~ s/[^-a-zA-Z0-9_:.]+/-/g;
    $t =~ s/[-:.]+$//;
    my $old = $t;
    my %s   = ( $full => 1 );
    my $ids = $self->{ids};
    return map $self->encode_entities($_), map {
        my $i = '';
        $i++ while $ids->{"$_$i"}++;
        "$_$i";
        }
        grep !$s{$_}++,
        grep defined,
        ( $first, $old );
}

# Custom handling of errata section

sub _gen_errata {
    return;    # override the default errata formatting
}

sub end_Document {
    my $self = shift;
    $self->_emit_custom_errata() if $self->{errata};
    $self->SUPER::end_Document(@_);
}

sub _emit_custom_errata {
    my $self = shift;

    my $tag = sub {
        my $name       = shift;
        my $attributes = '';
        if ( ref( $_[0] ) ) {
            my $attr = shift;
            while ( my ( $k, $v ) = each %$attr ) {
                $attributes .= qq{ $k="} . $self->encode_entities($v) . '"';
            }
        }
        my @body = map { /^</ ? $_ : $self->encode_entities($_) } @_;
        return join( '', "<$name$attributes>", @body, "</$name>" );
    };

    my @errors = map {
        my $line  = $_;
        my $error = $self->{'errata'}->{$line};
        (
            $tag->( 'dt', "Around line $line:" ),
            $tag->( 'dd', map { $tag->( 'p', $_ ) } @$error ),
        );
    } sort { $a <=> $b } keys %{ $self->{'errata'} };

    my $error_count = keys %{ $self->{'errata'} };
    my $s = $error_count == 1 ? '' : 's';

    $self->{'scratch'} = $tag->(
        'div',
        { id => "pod-errors" },
        $tag->( 'p', { class => 'title' }, "$error_count POD Error$s" ),
        $tag->(
            'div',
            { id => "pod-error-detail" },
            $tag->(
                'p',
                'The following errors were encountered while parsing the POD:'
            ),
            $tag->( 'dl', @errors ),
        ),
    );
    $self->emit;
}

1;

=pod

=head1 NAME

MetaCPAN::Pod::XHTML - Format Pod as HTML for MetaCPAN

=head1 ATTRIBUTES

=head2 link_mappings

=cut
