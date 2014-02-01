{   "name"           => "Encoding",
    "abstract"       => "Beyond 7bit ascii",
    "version"        => "1.1",
    "X_Module_Faker" => {
        "cpan_author"   => "RWSTAUNER",
        "omitted_files" => [ "META.json", "META.yml" ],
        "append"        => [
            {   "file" => "lib/Encoding/UTF8.pm",
                "content" =>
                    "package Encoding::UTF8;\n\nuse utf8;\nmy \$heart = qq<\342\235\244>;\n",
            },
            {   "file" => "lib/Encoding/CP1252.pm",
                "content" =>
                    "package Encoding::CP1252;\n\nsub bullet { qq<\x95-\xf7> }\n",
            },
        ],
    },
}
