{
    es => ($ENV{ES} || 'localhost:9900'),
    port => '5900',
    die_on_error => 1,
    level => ($ENV{TEST_VERBOSE} ? 'info' : 'warn'),
    cpan => 't/var/tmp/fakecpan',
    source_base => 't/var/tmp/source',
    logger => [{
        class => 'Log::Log4perl::Appender::Screen',
        name => 'testing'
    }]
}
