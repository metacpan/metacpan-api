{
    es => ':' . ($ENV{METACPAN_ES_TEST_PORT} ||= 9900),
    port => '5900',
    level => 'warn',
    cpan => 't/var/tmp/fakecpan',
    logger => [{
        class => 'Log::Log4perl::Appender::Screen',
        name => 'testing'
    }]
}
