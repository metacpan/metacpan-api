{
    components => 
    {
        schemas =>
        {
            # NOTE: schemas -> api_errors
            api_errors =>
            {
                description => q{Definition of standard errors returned by MetaCPAN API},
                properties =>
                {
                    code =>
                    {
                        description => q{A 3 digits code representing the error.},
                        maxLength => 3,
                        type => 'string',
                    },
                    message =>
                    {
                        description => q{The error message designed for human consumption with more details about the error.},
                        maxLength => 20000,
                        type => 'string',
                    },
                    param =>
                    {
                        description => q{If the error is parameter-specific, the parameter related to the error.},
                        maxLength => 2048,
                        type => 'string',
                    },
                },
                required => [
                    'code',
                ],
                title => 'APIErrors',
                type => 'object',
            },
            # NOTE: schemas -> author_mapping
            author_mapping =>
            {
                description => q{This is the object representing the availble fields for the [author object](https://explorer.metacpan.org/?url=/author/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/profile",
                    }
                },
            },
            # NOTE: schemas -> changes
            changes =>
            {
                description => q{This is the object representing a MetaCPAN [module changes file](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches)},
                properties =>
                {
                    author =>
                    {
                        type => 'string',
                    },
                    authorized =>
                    {
                        type => 'boolean',
                    },
                    binary =>
                    {
                        type => 'boolean',
                    },
                    category =>
                    {
                        type => 'string',
                    },
                    content =>
                    {
                        type => 'string',
                    },
                    date =>
                    {
                        type => 'string',
                    },
                    deprecated =>
                    {
                        type => 'boolean',
                    },
                    directory =>
                    {
                        type => 'boolean',
                    },
                    dist_fav_count =>
                    {
                        type => 'integer',
                    },
                    distribution =>
                    {
                        type => 'string',
                    },
                    download_url =>
                    {
                        type => 'string',
                    },
                    id =>
                    {
                        type => 'string',
                    },
                    indexed =>
                    {
                        type => 'boolean',
                    },
                    level =>
                    {
                        type => 'integer',
                    },
                    maturity =>
                    {
                        type => 'string',
                    },
                    mime =>
                    {
                        type => 'string',
                    },
                    module =>
                    {
                        items => 
                        {
                            type => 'string',
                        }
                    },
                    name =>
                    {
                        type => 'string',
                    },
                    path =>
                    {
                        type => 'string',
                    },
                    pod =>
                    {
                        type => 'string',
                    },
                    release =>
                    {
                        type => 'string',
                    },
                    sloc =>
                    {
                        type => 'integer',
                    },
                    slop =>
                    {
                        type => 'integer',
                    },
                    'stat' =>
                    {
                        properties =>
                        {
                            mode =>
                            {
                                type => 'integer',
                            },
                            mtime => 
                            {
                                type => 'integer',
                            },
                            size => 
                            {
                                type => 'integer',
                            }
                        },
                    },
                    status =>
                    {
                        type => 'string',
                    },
                    version =>
                    {
                        description => 'Package version string',
                        type => 'string',
                    },
                    version_numified =>
                    {
                        type => 'float',
                    }
                },
            },
            # NOTE: schemas -> cover
            cover =>
            {
                description => q{This is the object representing a MetaCPAN [module coverage](http://cpancover.com/)},
                properties =>
                {
                    criteria => 
                    {
                        description => 'CPAN Cover results',
                        properties =>
                        {
                            branch =>
                            {
                                description => 'Percentage of branch code coverage',
                                type => 'float',
                            },
                            condition =>
                            {
                                description => 'Percentage of condition code coverage',
                                type => 'float',
                            },
                            statement =>
                            {
                                description => 'Percentage of statement code coverage',
                                type => 'float',
                            },
                            subroutine =>
                            {
                                description => 'Percentage of subroutine code coverage',
                                type => 'float',
                            },
                            total =>
                            {
                                description => 'Percentage of total code coverage',
                                type => 'float',
                            }
                        },
                    },
                    distribution =>
                    {
                        description => 'Name of the distribution',
                        type => 'string',
                    },
                    release =>
                    {
                        description => 'Package name with version',
                        type => 'string',
                    },
                    url =>
                    {
                        description => 'URL for cpancover report',
                        type => 'string',
                    },
                    version =>
                    {
                        description => 'Package version string',
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> distribution
            distribution =>
            {
                description => q{This is the object representing a MetaCPAN [author distribution](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#distributiondistribution)},
                properties =>
                {
                    bugs => 
                    {
                        properties =>
                        {
                            github =>
                            {
                                properties =>
                                {
                                    active => { type => 'integer' },
                                    closed => { type => 'integer' },
                                    'open' => { type => 'integer' },
                                    source =>
                                    {
                                        maxLength => 2048,
                                        type => 'string',
                                    },
                                },
                            },
                            rt =>
                            {
                                properties =>
                                {
                                    '<html>' => { type => 'number' },
                                    active => { type => 'integer' },
                                    closed => { type => 'integer' },
                                    new => { type => 'integer' },
                                    'open' => { type => 'integer' },
                                    patched => { type => 'integer' },
                                    rejected => { type => 'integer' },
                                    resolved => { type => 'integer' },
                                    source =>
                                    {
                                        maxLength => 2048,
                                        type => 'string',
                                    },
                                    stalled => { type => 'integer' },
                                },
                            },
                        },
                    },
                    external_package => 
                    {
                        properties =>
                        {
                            cygwin =>
                            {
                                maxLength => 2048,
                                type => 'string',
                            },
                            debian =>
                            {
                                maxLength => 2048,
                                type => 'string',
                            },
                            fedora =>
                            {
                                maxLength => 2048,
                                type => 'string',
                            },
                        },
                    },
                    name => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    river => 
                    {
                        properties =>
                        {
                            bucket => { type => 'integer' },
                            bus_factor => { type => 'integer' },
                            immediate => { type => 'integer' },
                            total => { type => 'integer' },
                        },
                    },
                },
            },
            # NOTE: schemas -> distribution_mapping
            distribution_mapping =>
            {
                description => q{This is the object representing the availble fields for the [distribution object](https://explorer.metacpan.org/?url=/distribution/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/distribution",
                    }
                },
            },
            # NOTE: schemas -> download_url
            download_url =>
            {
                description => q{This is the object representing a MetaCPAN [distribution download URL](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#download_urlmodule)},
                properties =>
                {
                    checksum_md5 =>
                    {
                        type => 'string',
                    },
                    checksum_sha256 =>
                    {
                        type => 'string',
                    },
                    date =>
                    {
                        description => 'An ISO 8601 datetime',
                        type => 'string',
                    },
                    download_url =>
                    {
                        type => 'string',
                    },
                    release =>
                    {
                        type => 'string',
                    },
                    status =>
                    {
                        type => 'string',
                    },
                    version =>
                    {
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> error
            error =>
            {
                description => "An error response from the MetaCPAN API",
                properties =>
                {
                    error =>
                    {
                        '$ref' => '#/components/schemas/api_errors'
                    }
                },
                required => [
                    'error'
                ],
                type => 'object',
            },
            # NOTE: schemas -> favorite
            favorite =>
            {
                description => q{This is the object representing favorites},
                properties =>
                {
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    date => 
                    {
                        description => 'ISO8601 date format',
                        type => 'string'
                    },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    id => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    release => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    user => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> favorite_mapping
            favorite_mapping =>
            {
                description => q{This is the object representing the availble fields for the [favorite object](https://explorer.metacpan.org/?url=/favorite/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/favorite",
                    }
                },
            },
            # NOTE: schemas -> file
            file =>
            {
                description => q{This is the object representing a file},
                properties =>
                {
                    abstract => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    authorized => { type => 'boolean' },
                    binary => { type => 'boolean' },
                    date =>
                    {
                        description => 'ISO8601 date format',
                        type => 'string'
                    },
                    deprecated => { type => 'boolean' },
                    description => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    dir => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    directory => { type => 'boolean' },
                    dist_fav_count => { type => 'integer' },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    documentation => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    download_url => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    id => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    indexed => { type => 'boolean' },
                    level => { type => 'integer' },
                    maturity => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    mime => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    # See <https://github.com/metacpan/metacpan-api/blob/97b4791bf274bfb4e25f3a122e7115a2e9315404/lib/MetaCPAN/Document/File.pm#L150>
                    module => 
                    {
                        items =>
                        {
                            '$ref' => '#/components/schemas/module',
                        },
                        type => 'array',
                    },
                    name => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    path => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    pod => 
                    {
                        type => 'string',
                    },
                    pod_lines => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    release => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    sloc => { type => 'integer' },
                    slop => { type => 'integer' },
                    stat => 
                    {
                        properties =>
                        {
                            gid => { type => 'number' },
                            mode => { type => 'integer' },
                            mtime => { type => 'integer' },
                            size => { type => 'integer' },
                            uid => { type => 'number' },
                        },
                    },
                    status => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    # TODO Clueless as to what that could be. Find out
                    suggest => {},
                    version => { type => 'string' },
                    version_numified => { type => 'number' },
                },
            },
            # NOTE: schemas -> file_mapping
            file_mapping =>
            {
                description => q{This is the object representing the availble fields for the [file object](https://explorer.metacpan.org/?url=/module/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/file",
                    }
                },
            },
            # NOTE: schemas -> metadata
            metadata =>
            {
                properties =>
                {
                    abstract =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    author =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    dynamic_config =>
                    {
                        type => 'boolean',
                    },
                    generated_by =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    license => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    meta_spec => 
                    {
                        properties =>
                        {
                            url =>
                            {
                                maxLength => 2048,
                                type => 'string',
                            },
                            version =>
                            {
                                type => 'integer',
                            }
                        },
                    },
                    name =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    no_index =>
                    {
                        properties =>
                        {
                            directory =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                            package =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            }
                        }
                    },
                    prereqs =>
                    {
                        properties =>
                        {
                            build =>
                            {
                                properties =>
                                {
                                    requires =>
                                    {
                                        type => 'nested'
                                    }
                                }
                            },
                            configure =>
                            {
                                properties =>
                                {
                                    requires =>
                                    {
                                        type => 'nested'
                                    }
                                }
                            },
                            runtime =>
                            {
                                properties =>
                                {
                                    requires =>
                                    {
                                        type => 'nested'
                                    }
                                }
                            },
                            test =>
                            {
                                properties =>
                                {
                                    requires =>
                                    {
                                        type => 'nested'
                                    }
                                }
                            }
                        }
                    },
                    release_status =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    resources =>
                    {
                        properties => 
                        {
                            bugtracker =>
                            {
                                properties =>
                                {
                                    web =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                    type =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    }
                                }
                            },
                            repository =>
                            {
                                properties =>
                                {
                                    web =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                    type =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    }
                                }
                            },
                            homepage =>
                            {
                                type => 'string'
                            },
                            license =>
                            {
                                type => 'string'
                            }
                        },
                        type => 'nested'
                    },
                    version =>
                    {
                        type => 'string'
                    }
                },
            },
            # NOTE: schemas -> mirror
            mirror =>
            {
                description => q{This is the object representing a mirror},
                properties =>
                {
                    aka_name =>
                    {
                        type => 'string',
                    },
                    A_or_CNAME =>
                    {
                        type => 'string',
                    },
                    ccode =>
                    {
                        description => 'A 2-characters ISO 3166 country code',
                        maxLength => 2,
                        type => 'string',
                    },
                    city =>
                    {
                        type => 'string',
                    },
                    contact =>
                    {
                        items => 
                        {
                            contact_site =>
                            {
                                type => 'string',
                            },
                            contact_user =>
                            {
                                type => 'string',
                            },
                        },
                        type => 'array',
                    },
                    continent =>
                    {
                        type => 'string',
                    },
                    country =>
                    {
                        type => 'string',
                    },
                    distance =>
                    {
                        type => 'string',
                    },
                    distance =>
                    {
                        type => 'string',
                    },
                    dnsrr =>
                    {
                        type => 'string',
                    },
                    ftp =>
                    {
                        type => 'string',
                    },
                    freq =>
                    {
                        type => 'string',
                    },
                    http =>
                    {
                        type => 'string',
                    },
                    inceptdate =>
                    {
                        type => 'string',
                    },
                    location =>
                    {
                        items =>
                        {
                            type => 'string',
                        },
                        type => 'array',
                    },
                    name =>
                    {
                        type => 'string',
                    },
                    note =>
                    {
                        type => 'string',
                    },
                    org =>
                    {
                        type => 'string',
                    },
                    region =>
                    {
                        type => 'string',
                    },
                    reitredate =>
                    {
                        type => 'string',
                    },
                    rsync =>
                    {
                        type => 'string',
                    },
                    src =>
                    {
                        type => 'string',
                    },
                    tz =>
                    {
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> mirrors
            mirrors =>
            {
                description => q{This is the object representing a list of mirrors},
                properties =>
                {
                    mirrors => 
                    {
                        items =>
                        {
                            '$ref' => '#/components/schemas/mirror',
                        },
                        type => 'array',
                    },
                    total =>
                    {
                        type => 'integer',
                    },
                    took =>
                    {
                        type => 'integer',
                    },
                },
            },
            # NOTE: schemas -> module
            module =>
            {
                description => q{This is the object representing a module},
                properties =>
                {
                    abstract => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    # NOTE: This property is not found in file object
                    associated_pod => { type => 'string' },
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    authorized => { type => 'boolean' },
                    binary => { type => 'boolean' },
                    date =>
                    {
                        description => 'ISO8601 date format',
                        type => 'string'
                    },
                    deprecated => { type => 'boolean' },
                    description => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    dir => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    directory => { type => 'boolean' },
                    dist_fav_count => { type => 'integer' },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    documentation => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    download_url => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    id => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    indexed => { type => 'boolean' },
                    level => { type => 'integer' },
                    maturity => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    mime => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    # See <https://github.com/metacpan/metacpan-api/blob/97b4791bf274bfb4e25f3a122e7115a2e9315404/lib/MetaCPAN/Document/File.pm#L150>
                    module => 
                    {
                        '$ref' => '#/components/schemas/module',
                    },
                    name => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    path => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    pod => 
                    {
                        type => 'string',
                    },
                    pod_lines => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    release => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    sloc => { type => 'integer' },
                    slop => { type => 'integer' },
                    stat => 
                    {
                        properties =>
                        {
                            gid => { type => 'number' },
                            mode => { type => 'integer' },
                            mtime => { type => 'integer' },
                            size => { type => 'integer' },
                            uid => { type => 'number' },
                        },
                    },
                    status => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    # TODO Clueless as to what that could be. Find out
                    suggest => {},
                    version => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    version_numified => { type => 'number' },
                },
            },
            # NOTE: schemas -> module_mapping
            module_mapping =>
            {
                description => q{This is the object representing the availble fields for the [module object](https://explorer.metacpan.org/?url=/module/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/module",
                    }
                },
            },
            # NOTE: schemas -> package
            package =>
            {
                description => q{This is the object representing a MetaCPAN [module package](https://github.com/metacpan/metacpan-api/blob/master/lib/MetaCPAN/Document/Package.pm)},
                properties =>
                {
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    dist_version => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    file => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    module_name => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    version => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> permission
            permission =>
            {
                description => q{This is the object representing a MetaCPAN [module permission](https://github.com/metacpan/metacpan-api/blob/master/lib/MetaCPAN/Document/Permission.pm)},
                properties =>
                {
                    co_maintainers => 
                    {
                        items =>
                        {
                            maxLength => 2048,
                            type => 'string',
                        },
                        type => 'array',
                    },
                    module_name => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    owner => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                },
            },
            # NOTE: schemas -> profile
            profile =>
            {
                description => q{This is the object representing a MetaCPAN [author profile](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#authorauthor)},
                properties =>
                {
                    asciiname => 
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    blog => 
                    {
                        properties =>
                        {
                            feed => 
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                            url => 
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                        },
                    },
                    city => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    country => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    donation => 
                    {
                        items =>
                        {
                            anyOf => [
                            {
                                id => 
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                                name =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                            }],
                        },
                        type => 'array',
                    },
                    email => 
                    {
                        items =>
                        {
                            maxLength => 2048,
                            type => 'string',
                        },
                        type => 'array',
                    },
                    gravatar_url => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    is_pause_custodial_account => { type => 'boolean' },
                    # NOTE: although 'links' is present in data returned, it is undocumented
                    links =>
                    {
                        description => "An hash of key-URI pairs",
                        properties =>
                        {
                            backpan_directory => { type => 'string' },
                            cpan_directory => { type => 'string' },
                            cpantesters_matrix => { type => 'string' },
                            cpantesters_reports => { type => 'string' },
                            cpants => { type => 'string' },
                            metacpan_explorer => { type => 'string' },
                            repology => { type => 'string' },
                        },
                    },
                    # NOTE: location -> [ 52.847098, -8.98849 ]
                    location => 
                    {
                        items => 
                        {
                            type => 'number',
                        },
                        type => 'array',
                    },
                    name => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    pauseid => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    perlmongers => 
                    {
                        properties => 
                        {
                            name =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                            url =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                        },
                    },
                    profile => 
                    {
                        items =>
                        {
                            properties =>
                            {
                                id =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                                name =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                            },
                        },
                        type => 'array',
                    },
                    # NOTE: 'release_count' is present in data returned by the REST API, but is undocumented
                    release_count =>
                    {
                        properties =>
                        {
                            'backpan-only' => { type => 'integer' },
                            cpan => { type => 'integer' },
                            latest => { type => 'integer' },
                        },
                    },
                    region => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    updated => { type => 'string' },
                    user => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    website => 
                    {
                        items =>
                        {
                            maxLength => 2048,
                            type => 'string',
                        },
                        type => 'array',
                    },
                },
            },
            # NOTE: schemas -> rating
            rating =>
            {
                description => q{This is the object representing a rating)},
                properties =>
                {
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    date => 
                    {
                        description => 'ISO8601 datetime',
                        type => 'string',
                    },
                    # See <https://github.com/metacpan/metacpan-api/blob/97b4791bf274bfb4e25f3a122e7115a2e9315404/lib/MetaCPAN/Document/Rating.pm#L12>
                    details => 
                    {
                        properties =>
                        {
                            description =>
                            {
                                maxLength => 2048,
                                type => 'string',
                            },
                        },
                    },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    helpful => 
                    {
                        items =>
                        {
                            user =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                            value => { type => 'boolean' },
                        },
                        type => 'array',
                    },
                    rating => { type => 'number' },
                    release => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    user => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                },
            },
            # NOTE: schemas -> rating_mapping
            rating_mapping =>
            {
                description => q{This is the object representing the availble fields for the [rating object](https://explorer.metacpan.org/?url=/rating/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/rating",
                    }
                },
            },
            # NOTE: schemas -> release
            release =>
            {
                description => q{This is the object representing a release)},
                properties =>
                {
                    abstract => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    archive => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    author => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    authorized => { type => 'boolean' },
                    changes_file => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    checksum_md5 => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    checksum_sha256 => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    date => 
                    {
                        description => 'ISO8601 datetime',
                        type => 'string',
                    },
                    dependency => 
                    {
                        items => 
                        {
                            type => 'object',
                            properties =>
                            {
                                module =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                                phase =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                                relationship =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                                version =>
                                {
                                    maxLength => 2048,
                                    type => 'string'
                                },
                            },
                        },
                        type => 'array',
                    },
                    deprecated => { type => 'boolean' },
                    distribution => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    download_url => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    first => { type => 'boolean' },
                    id => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    license => 
                    {
                        items => 
                        {
                            # e.g.: perl_5
                            maxLength => 2048,
                            type => 'string',
                        },
                        type => 'array',
                    },
                    main_module => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    maturity => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    metadata =>
                    {
                        schema =>
                        {
                            '$ref' => '#/components/schemas/metadata',
                        }
                    },
                    name => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    provides => 
                    {
                        items =>
                        {
                            maxLength => 2048,
                            type => 'string'
                        },
                        type => 'array'
                    },
                    # See <https://github.com/metacpan/metacpan-api/blob/97b4791bf274bfb4e25f3a122e7115a2e9315404/lib/MetaCPAN/Types/TypeTiny.pm#L74>
                    resources => 
                    {
                        properties =>
                        {
                            bugtracker =>
                            {
                                properties =>
                                {
                                    mailto =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                    web =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                },
                            },
                            homepage =>
                            {
                                maxLength => 2048,
                                type => 'string'
                            },
                            license =>
                            {
                                items =>
                                {
                                    maxLength => 2048,
                                    type => 'string',
                                },
                                type => 'array',
                            },
                            repository =>
                            {
                                properties =>
                                {
                                    type =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                    url =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                    web =>
                                    {
                                        maxLength => 2048,
                                        type => 'string'
                                    },
                                },
                            },
                        },
                    },
                    stat => 
                    {
                        properties =>
                        {
                            gid => { type => 'number' },
                            mode => { type => 'integer' },
                            mtime => { type => 'integer' },
                            size => { type => 'integer' },
                            uid => { type => 'number' },
                        },
                    },
                    status => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    tests => 
                    {
                        properties =>
                        {
                            fail => { type => 'integer' },
                            na => { type => 'integer' },
                            pass => { type => 'integer' },
                            unknown => { type => 'integer' },
                        },
                    },
                    version => 
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                    version_numified => { type => 'number' },
                },
            },
            # NOTE: schemas -> release_mapping
            release_mapping =>
            {
                description => q{This is the object representing the availble fields for the [release object](https://explorer.metacpan.org/?url=/release/_mapping).},
                properties => 
                {
                    schema =>
                    {
                        '$ref' => "#/components/schemas/release",
                    }
                },
            },
            # NOTE: schemas -> result_set
            result_set =>
            {
                description => q{This is the object representing a search result set)},
                properties =>
                {
                    hits => 
                    {
                        properties =>
                        {
                            hits => 
                            {
                                items => 
                                {
                                    properties =>
                                    {
                                        _id => { type => 'string' },
                                        _index => 
                                        {
                                            description => "For example: cpan_v1_01",
                                            type => "string",
                                        },
                                        _score => { type => 'number' },
                                        _source => 
                                        {
                                            oneOf => [
                                                { '$ref' => '#/components/schemas/author' },
                                                { '$ref' => '#/components/schemas/distribution' },
                                                { '$ref' => '#/components/schemas/favorite' },
                                                { '$ref' => '#/components/schemas/favorite' },
                                                { '$ref' => '#/components/schemas/file' },
                                                { '$ref' => '#/components/schemas/rating' },
                                                { '$ref' => '#/components/schemas/release' },
                                            ],
                                        },
                                        _type => 
                                        {
                                            anyOf => [qw( author distribution favorite file rating release )],
                                            type => 'enum',
                                        },
                                    },
                                },
                                type => 'array',
                            },
                            total => { type => 'integer' },
                            max_score => { type => 'number' },
                        },
                    },
                    _shards => 
                    {
                        properties =>
                        {
                            total =>  { type => 'integer' },
                            successful => { type => 'integer' },
                            failed => { type => 'integer' },
                        },
                    },
                    took => { type => 'integer' },
                    timed_out => { type => 'boolean' },
                },
            },
            # NOTE: schemas -> reverse_dependencies
            reverse_dependencies =>
            {
                description => q{This is the object representing a reverse dependencies result set)},
                properties =>
                {
                    data => 
                    {
                        items =>
                        {
                            schema =>
                            {
                                '$ref' => '#/components/schemas/release',
                            },
                        },
                        type => 'array',
                    },
                    took => { type => 'integer' },
                    timed_out => { type => 'boolean' },
                },
            },
            # NOTE: schemas -> search
            search =>
            {
                description => q{This is the object representing a search query)},
                properties => 
                {
                    aggs =>
                    {
                        description => "Specifies the aggregation method for the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#post-searches).",
                        properties =>
                        {
                            license =>
                            {
                                properties =>
                                {
                                    terms => 
                                    {
                                        properties =>
                                        {
                                            field =>
                                            {
                                                type => 'string',
                                            },
                                            size =>
                                            {
                                                type => 'integer',
                                            },
                                        },
                                    }
                                },
                                type => 'object',
                            }
                        },
                    },
                    fields =>
                    {
                        description => "Specifies which fields in the response should be provided.",
                        type => 'array',
                    },
                    filter =>
                    {
                        description => "",
                        properties =>
                        {
                            'and' =>
                            {
                                items =>
                                {
                                    anyOf => [
                                        { 'exists' => { type => 'object', }, },
                                        { missing => { type => 'object', }, },
                                        { term => { type => 'object', }, },
                                    ],
                                },
                                type => 'array',
                            },
                            'not' =>
                            {
                                items =>
                                {
                                    anyOf => [
                                        { 'exists' => { type => 'object', }, },
                                        { missing => { type => 'object', }, },
                                        { term => { type => 'object', }, },
                                    ],
                                },
                                type => 'array',
                            },
                            'or' =>
                            {
                                items =>
                                {
                                    anyOf => [
                                        { 'exists' => { type => 'object', }, },
                                        { missing => { type => 'object', }, },
                                        { term => { type => 'object', }, },
                                    ],
                                },
                                type => 'array',
                            },
                        },
                        type => 'object',
                    },
                    query =>
                    {
                        description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#post-searches).",
                        type => 'string',
                    },
                    size =>
                    {
                        description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#post-searches) result elements.",
                        type => 'integer',
                    },
                    sort =>
                    {
                        description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#post-searches) result.",
                        type => 'string',
                    },
                },
            },
        },
    },
    info =>
    {
        contact =>
        {
            email => 'admin@metacpan.org',
            name => 'CPAN Administrators',
            url => 'https://metacpan.org',
        },
        description => 'The MetaCPAN REST API. Please see https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md for more details.',
        termsOfService => "https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#being-polite",
        title => 'MetaCPAN API',
        version => '2023-07-27',
    },
    openapi => '3.0.0',
    paths =>
    {
        # NOTE: /v1/author
        '/v1/author' =>
        {
            get => 
            {
                description => 'Retrieves author information details.',
                operationId => 'GetAuthor',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/author/{author}
        '/v1/author/{author}' =>
        {
            get => 
            {
                description => 'Retrieves an author information details.',
                operationId => 'GetAuthorProfile',
                parameters => [
                {
                    in => 'path',
                    name => 'author',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which object to [join](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#joins) in the result.",
                    in => 'query',
                    name => 'join',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/profile",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/author/_mapping
        '/v1/author/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [author object](https://explorer.metacpan.org/?url=/author/_mapping).},
                operationId => 'GetAuthorMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/author_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/author/_search
        '/v1/author/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the author search.},
                operationId => 'GetAuthorSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the author search.},
                operationId => 'PostAuthorSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/author/_search
        '/v1/author/_search/scroll' =>
        {
            'delete' =>
            {
                description => qq{Clear a [scroll](https://www.elastic.co/guide/en/elasticsearch/reference/8.9/paginate-search-results.html#clear-scroll)},
                operationId => 'DeleteAuthorSearchScroll',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/json' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                oneOf => [
                                    {
                                        properties => 
                                        {
                                            scroll_id =>
                                            {
                                                type => 'string',
                                            },
                                        },
                                    },
                                    {
                                        properties => 
                                        {
                                            scroll_id =>
                                            {
                                                items =>
                                                {
                                                    type => 'string',
                                                },
                                                type => 'array',
                                            },
                                        },
                                    },
                                ],
                            }
                        }
                    },
                    required => \1,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    properties =>
                                    {
                                        # TODO: Need to find out what is returned upon clearing a scroll
                                        removed =>
                                        {
                                            type => 'boolean',
                                        }
                                    }
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/changes/{module}
        '/v1/changes/{module}' =>
        {
            get => 
            {
                description => 'Retrieves a distribution Changes file details.',
                operationId => 'GetChangesFile',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/changes",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/cover/{cover}
        '/v1/cover/{cover}' =>
        {
            get => 
            {
                description => 'Retrieves a module cover details.',
                operationId => 'GetModuleCover',
                parameters => [
                {
                    in => 'path',
                    name => 'cover',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/cover",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/distribution/{distribution}
        '/v1/distribution/{distribution}' =>
        {
            get => 
            {
                description => 'The `/distribution` endpoint accepts the name of a distribution (e.g. [/distribution/Moose](https://fastapi.metacpan.org/v1/distribution/Moose)), which returns information about the distribution which is not specific to a version (like RT bug counts)',
                operationId => 'GetModuleDistribution',
                parameters => [
                {
                    in => 'path',
                    name => 'distribution',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/distribution",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/distribution/_mapping
        '/v1/distribution/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [distribution object](https://explorer.metacpan.org/?url=/distribution/_mapping).},
                operationId => 'GetDistributionMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/distribution_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/distribution/_search
        '/v1/distribution/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the distribution search.},
                operationId => 'GetDistributionSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the distribution search.},
                operationId => 'PostDistributionSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/download_url/{module}
        '/v1/download_url/{module}' =>
        {
            get => 
            {
                description => qq{Retrieves a download URL for a given module.\nThe `/download_url` endpoint exists specifically for the `cpanm` client.  It takes a module name with an optional version (or range of versions) and an optional `dev` flag (for development releases) and returns a `download_url` as well as some other helpful info.\n\nObviously anyone can use this endpoint, but we'll only consider changes to this endpoint after considering how `cpanm` might be affected.},
                operationId => 'GetDownloadURL',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/download_url",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/favorite
        '/v1/favorite' =>
        {
            get => 
            {
                description => 'Retrieves favorites information details.',
                operationId => 'GetFavorite',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/favorite/_mapping
        '/v1/favorite/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [favorite object](https://explorer.metacpan.org/?url=/favorite/_mapping).},
                operationId => 'GetFavoriteMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/favorite_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/favorite/_search
        '/v1/favorite/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the favorite search.},
                operationId => 'GetFavoriteSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the favorite search.},
                operationId => 'PostFavoriteSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/file
        '/v1/file' =>
        {
            get => 
            {
                description => 'Retrieves a file information details.',
                operationId => 'GetFile',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/file/_mapping
        '/v1/file/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [file object](https://explorer.metacpan.org/?url=/file/_mapping).},
                operationId => 'GetFileMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/file_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/file/_search
        '/v1/file/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the file search.},
                operationId => 'GetFileSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the file search.},
                operationId => 'PostFileSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/mirror
        '/v1/mirror' =>
        {
            get => 
            {
                description => qq{Returns a `mirrors` object containing a list of `mirror` objects. Currently, the API only returns one mirror, because CPAN now uses CDN instead of mirrors.},
                operationId => 'GetMirror',
                parameters => [
                {
                    description => "Specifies an optional keyword to find the matching mirrors.",
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/mirrors",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/module
        '/v1/module' =>
        {
            get => 
            {
                description => 'Retrieves module information details.',
                operationId => 'GetModule',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/module/{module}
        '/v1/module/{module}' =>
        {
            get => 
            {
                description => qq{Returns the corresponding `file` of the latest version of the `module`. Considering that Moose-2.0001 is the latest release, the result of [/module/Moose](https://fastapi.metacpan.org/v1/module/Moose) is the same as [/file/DOY/Moose-2.0001/lib/Moose.pm](https://fastapi.metacpan.org/v1/file/DOY/Moose-2.0001/lib/Moose.pm).},
                operationId => 'GetModuleFile',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which object to [join](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#joins) in the result.",
                    in => 'query',
                    name => 'join',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/file",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/module/_mapping
        '/v1/module/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [module object](https://explorer.metacpan.org/?url=/module/_mapping).},
                operationId => 'GetModuleMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/module_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/package
        '/v1/package' =>
        {
            get => 
            {
                description => 'Retrieves package information details.',
                operationId => 'GetPackage',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/package/{module}
        '/v1/package/{module}' =>
        {
            get => 
            {
                description => qq{Returns the corresponding `package` for the specified `module`. For example, [/package/Moose](https://fastapi.metacpan.org/v1/package/Moose).},
                operationId => 'GetModulePackage',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/package",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/permission
        '/v1/permission' =>
        {
            get => 
            {
                description => 'Retrieves permission information details.',
                operationId => 'GetPermission',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/permission/{module}
        '/v1/permission/{module}' =>
        {
            get => 
            {
                description => qq{Returns the corresponding `permission` for the specified `module`. For example, [/permission/Moose](https://fastapi.metacpan.org/v1/permission/Moose).},
                operationId => 'GetModulePermission',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/permission",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/pod/{module}
        '/v1/pod/{module}' =>
        {
            get => 
            {
                description => qq{Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [/pod/Moose?content-type=text/plain](https://fastapi.metacpan.org/v1/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:\n\n* text/html (default)\n* text/plain\n* text/x-pod\n* text/x-markdown},
                operationId => 'GetModulePOD',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => qq{You can change the output format by either passing a `content-type` query parameter (e.g. [/pod/Moose?content-type=text/plain](https://fastapi.metacpan.org/v1/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:\n\n* text/html (default)\n* text/plain\n* text/x-pod\n* text/x-markdown},
                    in => 'query',
                    name => 'content-type',
                    required => \0,
                    # TODO: Need to find out and set the correct openapi definition for query string
                    schema =>
                    {
                        properties =>
                        {
                            'content-type' =>
                            {
                                enum => [qw( text/html text/plain text/x-pod text/x-markdown )],
                                type => 'string',
                                maxLength => 2048,
                            },
                        },
                        required => [],
                        title => 'query_param',
                        type => 'object',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'text/html' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/plain' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/x-pod' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/x-markdown' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/pod/{author}/{release}/{path}
        '/v1/pod/{author}/{release}/{path}' =>
        {
            get => 
            {
                description => qq{Returns the POD of the given module. You can change the output format by either passing a `content-type` query parameter (e.g. [/pod/Moose?content-type=text/plain](https://fastapi.metacpan.org/v1/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:\n\n* text/html (default)\n* text/plain\n* text/x-pod\n* text/x-markdown},
                operationId => 'GetModuleReleasePod',
                parameters => [
                {
                    in => 'path',
                    name => 'release',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    in => 'path',
                    name => 'path',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => qq{You can change the output format by either passing a `content-type` query parameter (e.g. [/pod/Moose?content-type=text/plain](https://fastapi.metacpan.org/v1/pod/Moose?content-type=text/plain) or by adding an `Accept` header to the HTTP request. Valid content types are:\n\n* text/html (default)\n* text/plain\n* text/x-pod\n* text/x-markdown},
                    in => 'query',
                    name => 'content-type',
                    required => \0,
                    schema =>
                    {
                        properties =>
                        {
                            'content-type' =>
                            {
                                enum => [qw( text/html text/plain text/x-pod text/x-markdown )],
                                type => 'string',
                                maxLength => 2048,
                            },
                        },
                        required => [],
                        title => 'query_param',
                        type => 'object',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'text/html' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/plain' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/x-pod' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                            'text/x-markdown' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            },
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/rating
        '/v1/rating' =>
        {
            get => 
            {
                description => 'Retrieves rating information details.',
                operationId => 'GetRating',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/rating/_mapping
        '/v1/rating/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [rating object](https://explorer.metacpan.org/?url=/rating/_mapping).},
                operationId => 'GetRatingMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/rating_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/rating/_search
        '/v1/rating/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the rating search.},
                operationId => 'GetRatingSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the rating search.},
                operationId => 'PostRatingSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release
        '/v1/release' =>
        {
            get => 
            {
                description => 'Retrieves release information details.',
                operationId => 'GetRelease',
                parameters => [
                {
                    in => 'query',
                    name => 'q',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release/{distribution}
        '/v1/release/{distribution}' =>
        {
            get => 
            {
                description => qq{Retrieves an author information details.\nThe `/release` endpoint accepts either the name of a `distribution` (e.g. [/release/Moose](https://fastapi.metacpan.org/v1/release/Moose)), which returns the most recent release of the distribution.},
                operationId => 'GetReleaseDistribution',
                parameters => [
                {
                    in => 'path',
                    name => 'distribution',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which object to [join](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#joins) in the result.",
                    in => 'query',
                    name => 'join',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/release",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release/{author}/{release}
        '/v1/release/{author}/{release}' =>
        {
            get => 
            {
                description => qq{Retrieves an distribution release information details.\nThis `/release` endpoint accepts  the name of an `author` and the name of the `release` (e.g. [/release/DOY/Moose-2.0001](https://fastapi.metacpan.org/v1/release/DOY/Moose-2.0001)), which returns the most recent release of the distribution.},
                operationId => 'GetAuthorReleaseDistribution',
                parameters => [
                {
                    in => 'path',
                    name => 'author',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    in => 'path',
                    name => 'release',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which object to [join](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#joins) in the result.",
                    in => 'query',
                    name => 'join',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/release",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release/recent
        '/v1/release/recent' =>
        {
            get => 
            {
                description => qq{Get recent releases},
                operationId => 'GetReleaseRecent',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    properties =>
                                    {
                                        releases =>
                                        {
                                            items =>
                                            {
                                                properties =>
                                                {
                                                    abstract =>
                                                    {
                                                        type => 'string',
                                                    },
                                                    author =>
                                                    {
                                                        type => 'string',
                                                    },
                                                    date =>
                                                    {
                                                        type => 'string',
                                                    },
                                                    distribution =>
                                                    {
                                                        type => 'string',
                                                    },
                                                    name =>
                                                    {
                                                        type => 'string',
                                                    },
                                                    status =>
                                                    {
                                                        type => 'string',
                                                    },
                                                },
                                            },
                                            type => 'array',
                                        },
                                        total => 
                                        {
                                            type => 'integer',
                                        },
                                        took => 
                                        {
                                            type => 'integer',
                                        },
                                    },
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release/_mapping
        '/v1/release/_mapping' =>
        {
            get => 
            {
                description => qq{Returns the available fields for the [release object](https://explorer.metacpan.org/?url=/release/_mapping).},
                operationId => 'GetReleaseMapping',
                parameters => [],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/release_mapping",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/release/_search
        '/v1/release/_search' =>
        {
            get => 
            {
                description => qq{Returns the result set for the release search.},
                operationId => 'GetReleaseSearch',
                parameters => [
                {
                    description => "Specifies the [search query](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches).",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    type => 'string',
                },
                {
                    description => "Specifies the maximum number of [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result elements.",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'string',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
            post => 
            {
                description => qq{Returns the result set for the release search.},
                operationId => 'PostReleaseSearch',
                parameters => [
                {
                    in => 'query',
                    name => 'query',
                    required => \1,
                    type => 'string',
                },
                {
                    in => 'query',
                    name => 'size',
                    required => \0,
                    type => 'integer',
                },
                {
                    description => "Specifies the elements to sort the [search](https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md#get-searches) result.",
                    in => 'query',
                    name => 'sort',
                    required => \0,
                    type => 'string',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    type => 'array',
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                '$ref' => '#/components/schemas/search',
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/reverse_dependencies/dist/{module}
        '/v1/reverse_dependencies/dist/{module}' =>
        {
            get => 
            {
                description => qq{Returns a list of all the modules who depend on the specified module.`.},
                operationId => 'GetReverseDependencyDist',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/reverse_dependencies",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/search
        '/v1/search' =>
        {
            get => 
            {
                description => qq{Returns result set based on the search query.`.},
                operationId => 'GetSearchResult',
                parameters => [
                {
                    description => "Specifies the search keywords to be queried.",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/search/autocomplete
        '/v1/search/autocomplete' =>
        {
            get => 
            {
                description => qq{Returns result set based on the autocomplete search query.`.},
                operationId => 'GetSearchAutocompleteResult',
                parameters => [
                {
                    description => "Specifies the search keyword to be queried.",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/search/autocomplete/suggest
        '/v1/search/autocomplete/suggest' =>
        {
            get => 
            {
                description => qq{Returns suggested result set based on the autocomplete search query.`.},
                operationId => 'GetSearchAutocompleteSuggestResult',
                parameters => [
                {
                    description => "Specifies the search keyword to be queried.",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/search/first
        '/v1/search/first' =>
        {
            get => 
            {
                description => qq{Perform API search and return the first result (I'm Feeling Lucky)},
                operationId => 'GetSearchFirstResult',
                parameters => [
                {
                    description => "Specifies the search keywords to be queried.",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    properties =>
                                    {
                                        path =>
                                        {
                                            type => 'string',
                                            description => "Relative path to module with full name",
                                        },
                                        authorized =>
                                        {
                                            type => 'boolean',
                                        },
                                        description =>
                                        {
                                            type => 'string',
                                            description => "Module description",
                                        },
                                        id =>
                                        {
                                            type => 'string',
                                        },
                                        distribution =>
                                        {
                                            type => 'string',
                                            description => "Name of the distribution the module is contained in",
                                        },
                                        author =>
                                        {
                                            type => 'string',
                                            description => "Module author ID",
                                        },
                                        release =>
                                        {
                                            type => 'string',
                                            description => "Package name with version",
                                        },
                                        status =>
                                        {
                                            type => 'string',
                                        },
                                        'abstract.analyzed' =>
                                        {
                                            type => 'string',
                                            description => "The module's abstract as analyzed from POD",
                                        },
                                        dist_fav_count =>
                                        {
                                            type => 'integer',
                                            description => "Number of times favorited",
                                        },
                                        date =>
                                        {
                                            type => 'string',
                                            description => "date module was indexed",
                                        },
                                        documentation =>
                                        {
                                            type => 'string',
                                        },
                                        pod_lines =>
                                        {
                                            type => 'array',
                                        },
                                        items =>
                                        {
                                            type => 'integer',
                                        },
                                        indexed =>
                                        {
                                            type => 'boolean',
                                            description => "Is the module indexed by PAUSE",
                                        },
                                    },
                                    type => 'object',
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/search/web
        '/v1/search/web' =>
        {
            get => 
            {
                description => qq{Perform API search in the same fashion as the Web UI},
                operationId => 'GetSearchWebResult',
                parameters => [
                {
                    description => "The query search term. If the search term contains a term with the tags `dist:` or `module:` results will be in expanded form, otherwise collapsed form.\n\nSee also `collapsed`",
                    in => 'query',
                    name => 'q',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                },
                {
                    description => "The offset to use in the result set",
                    in => 'query',
                    name => 'from',
                    required => \0,
                    schema =>
                    {
                        default => 0,
                        type => 'integer',
                    },
                    style => 'simple',
                },
                {
                    description => "Number of results per page",
                    in => 'query',
                    name => 'size',
                    required => \0,
                    schema =>
                    {
                        default => 20,
                        type => 'integer',
                    },
                    style => 'simple',
                },
                {
                    description => "Force a collapsed even when searching for a particular distribution or module name.",
                    in => 'query',
                    name => 'collapsed',
                    required => \0,
                    schema =>
                    {
                        type => 'boolean',
                    },
                    style => 'simple',
                },
                {
                    description => "Specifies which fields in the response should be provided.",
                    in => 'query',
                    name => 'fields',
                    required => \0,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string'
                    },
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'application/json' =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/result_set",
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
        # NOTE: /v1/source/{module}
        '/v1/source/{module}' =>
        {
            get => 
            {
                description => qq{Returns the full source of the latest, authorized version of the given `module`.},
                operationId => 'GetModuleSource',
                parameters => [
                {
                    in => 'path',
                    name => 'module',
                    required => \1,
                    schema =>
                    {
                        maxLength => 2048,
                        type => 'string',
                    },
                    style => 'simple',
                }],
                requestBody =>
                {
                    content =>
                    {
                        'application/x-www-form-urlencoded' =>
                        {
                            encoding => {},
                            schema =>
                            {
                                additionalProperties => \0,
                                properties => {},
                                type => 'object'
                            }
                        }
                    },
                    required => \0,
                },
                responses =>
                {
                    200 =>
                    {
                        content =>
                        {
                            'text/plain' =>
                            {
                                schema =>
                                {
                                    format => 'binary',
                                    type => 'string',
                                }
                            }
                        },
                        description => 'Successful response.',
                    },
                    default =>
                    {
                        content =>
                        {
                            "application/json" =>
                            {
                                schema =>
                                {
                                    '$ref' => "#/components/schemas/error",
                                }
                            }
                        },
                        description => "Error response.",
                    }
                }
            },
        },
    },
    security => [],
    servers => [
        { url => 'https://fastapi.metacpan.org' },
    ],
}
