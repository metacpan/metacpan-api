{   "name"           => "Encoding",
    "abstract"       => "Beyond 7bit ascii",
    "version"        => "1.0",
    "X_Module_Faker" => {
        "cpan_author"   => "RWSTAUNER",
        "omitted_files" => [ "META.json", "META.yml" ],
        "append"        => [
            {   "file" => "lib/Encoding/CP1252.pm",
                "content" =>
                    "package Encoding::CP1252;\n\nsub bullet { qq<\x{95}> }\n",
            },
        ],
    },
}
