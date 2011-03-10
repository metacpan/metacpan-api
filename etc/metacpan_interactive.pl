use FindBin;
{
    level => 'debug',
    logger => [{
        class => 'Log::Log4perl::Appender::ScreenColoredLevels',
        stdout => 0,
    }, {
        class => 'Log::Log4perl::Appender::File',
        filename => $FindBin::RealBin . '/../var/log/metacpan.log',
        syswrite => 1,
    }]
}