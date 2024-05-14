use strict;
use warnings;
use lib 't/lib';

use Test::More;

use MetaCPAN::Pod::Renderer ();

my $factory       = MetaCPAN::Pod::Renderer->new();
my $html_renderer = $factory->html_renderer;
$html_renderer->index(0);

my $got = q{};

my $source = <<'EOF';
=pod

=head1 DESCRIPTION
L<Plack>
=cut
EOF

{
    my $html = <<'EOF';
<h1 id="DESCRIPTION-Plack"><a id="DESCRIPTION"></a>DESCRIPTION <a href="https://metacpan.org/pod/Plack">Plack</a></h1>

EOF

    $html_renderer->output_string( \$got );
    $html_renderer->parse_string_document($source);
    is( $got, $html, 'XHTML linkifies to metacpan by default' );
}

{
    my $md = <<'EOF';
# DESCRIPTION
[Plack](https://metacpan.org/pod/Plack)
EOF

    is( $factory->to_markdown($source), $md, 'markdown' );
}

{
    my $text = <<'EOF';
DESCRIPTION
Plack
EOF

    is( $factory->to_text($source), $text, 'text' );
}

{
    my $pod = <<'EOF';
=pod

=head1 DESCRIPTION
L<Plack>

=cut
EOF

    is( $factory->to_pod($source), $pod, 'pod' );
}
done_testing();
