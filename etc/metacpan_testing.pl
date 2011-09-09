{
    es => ':9900',
    port => '5900',
    level => 'info',
    cpan => 't/var/tmp/fakecpan',
    logger => [{
        class => 'Log::Log4perl::Appender::TestBuffer',
        name => 'testing'
    }]
}