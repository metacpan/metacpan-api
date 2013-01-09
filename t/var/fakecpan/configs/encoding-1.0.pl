{
  "name"     => "Encoding",
  "abstract" => "Beyond 7bit ascii",
  "version"  => "1.0",
  "X_Module_Faker" => {
    "cpan_author" => "RWSTAUNER",
    "append" => [
      {
        "file"     => "lib/Encoding/CP1252.pm",
        "encoding" => "cp1252",
        "content"  => "package Encoding::CP1252;\n\nsub bullet { qq<\x{95}> }\n",
      },
    ],
  },
}
