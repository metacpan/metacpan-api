{
    es => ':' . ($ENV{METACPAN_ES_TEST_PORT} ||= 9900),
    port => '5900',
    level => 'warn',
    cpan => 't/var/tmp/fakecpan',
    source_base => 't/var/tmp/source',
    logger => [{
        class => 'Log::Log4perl::Appender::Screen',
        name => 'testing'
    }]
}
