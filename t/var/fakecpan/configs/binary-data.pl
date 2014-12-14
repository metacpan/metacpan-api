## no critic
{
  name      => 'Binary-Data',
  abstract  => 'Binary after __DATA__ token',
  version   => '0.01',

  # Specify provides so that both modules are included
  # in release 'provides' list and the release will get marked as latest.
  provides  => {
    'Binary::Data' => {
      file    => 'lib/Binary/Data.pm',
      version => '0.01'
    },
    'Binary::Data::WithPod' => {
      file    => 'lib/Binary/Data/WithPod.pm',
      version => '0.02'
    }
  },

  X_Module_Faker => {
    cpan_author => 'BORISNAT',
    append => [ {
        file    => 'lib/Binary/Data.pm',
        content => <<EOF
# Module::Faker should prepend 3 lines above this

  'hello';
  __DATA__
BORK\0\0
\1
=F\0?}\xc2\xa0\0?}\xc2\x50
not pod
\0

=he\x50\x00\x7b
EOF
    },
    {
        'file'    => 'lib/Binary/Data/WithPod.pm',
        'content' => <<EOF
# Module::Faker should prepend 3 lines above this

=head1 NAME

Binary::Data::WithPod - that's it

=cut

  'hello';
  __DATA__
BORK\0\0
\1
=F\0?}\xc2\xa0\x0?}\xc2\x80
not pod

=buzz9\xf0\x9f\x98\x8e
\0
\0\1

=head1 DESCRIPTION

razzberry
pudding

=cut
EOF
    } ]
  }
}
