{
  "name"     => "Encoding",
  "abstract" => "Beyond 7bit ascii",
  "version"  => "1.2",
  "X_Module_Faker" => {
    "cpan_author" => "RWSTAUNER",
    "omitted_files" => ["META.json", "META.yml"],
    "append" => [
      {
        "file"     => "lib/Encoding/UTF8.pm",
        "content"  => "package Encoding::UTF8;\n\nuse utf8;\nmy \$heart = qq<\342\231\245>;\n",
      },
    ],
  },
}
