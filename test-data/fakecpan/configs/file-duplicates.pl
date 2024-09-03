use strict;
do {
    # Module::Faker doesn't pass *all* attributes (like no_index)
    # so we need to pass the content for our own META.json.
    # In order to avoid a ton of repetition (which is prone to bugs)
    # use perl to build a hash for reuse then encode the json ourselves.
    require JSON;

    # We'll include these provides in our custom META.json.
    my $provides = {
        'File::Duplicates' => {
            file    => 'lib/File/Duplicates.pm',
            version => '0.991',
        },
        'File::lib::File::Duplicates' => {
            file    => 'lib/File/lib/File/Duplicates.pm',
            version => '0.992',
        },
        'Dupe' => {
            file    => 'Dupe.pm',
            version => '0.993',
        },
        'DupeX::Dupe' => {
            file    => 'DupeX/Dupe.pm',
            version => '0.994',
        },
        'DupeX::Dupe::X' => {
            file    => 'DupeX/Dupe.pm',
            version => '0.995',
        },
    };

    my $meta = {
        name     => 'File-Duplicates',
        author   => 'BORISNAT',
        abstract =>
            'A dist with duplicate file names in different directories',
        version  => '1.000',
        no_index => {
            directory => ['c'],
        },
        generated_by   => 'hand',
        release_status => 'stable',
        dynamic_config => 0,
        license        => ['unknown'],
        'meta-spec'    => {
            'version' => 2,
            'url'     => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec'
        },

       # Pass some packages so that Module::Faker will add them to 02packages
       # and this dist will get 'status' => 'latest'
       # but omit the Dupe packages since the paths are explicitly not correct
       # and we don't want Module::Faker to generate the missing ones for us.
        provides => {
            map { ( $_ => $provides->{$_} ) } grep {/File/} keys %$provides
        },
    };

    $meta->{X_Module_Faker} = {
        omitted_files => [ 'META.json', ],
        cpan_author   => $meta->{author},
        append        => [
            {
                file    => 'META.json',
                content =>
                    JSON::encode_json( { %$meta, provides => $provides } ),
            },
            {
                file    => 'lib/File/Duplicates.pm',
                content => 'shortest path',
            },
            {
                file    => 'lib/File/lib/File/Duplicates.pm',
                content => 'dumb',
            },
            {
                file    => 'c/lib/File/Duplicates.pm',
                content => 'no_index',
            },
            {
                file    => 't/lib/File/Duplicates.pm',
                content => 'automatic no_index (t)',
            },
            {
                file    => 'c/Dupe.pm',
                content => 'short path but no_index',
            },
            {
                file    => 'lib/Dupe.pm',
                content =>
                    'shortest indexed path though metadata is probably wrong',
            },
            {
                file    => 'DupeX/Dupe.pm',
                content => 'shortest path for 2 (not 3) modules',
            },
        ],
    };
    $meta;    # return
};
