package MetaCPAN::Role::Common;

use Moose::Role;
use ElasticSearch;
use Log::Contextual qw( set_logger );
use Log::Log4perl ':easy';

has 'cpan' => ( is         => 'rw',
                isa        => 'Str',
                lazy_build => 1, );

has 'level' => ( is         => 'ro', isa => 'Str', default => 'info' );

has 'es' => ( is => 'rw', lazy_build => 1 );

has logger => ( is => 'ro', lazy_build => 1, predicate => 'has_logger' );

my $log;
sub _build_logger {
    my $self = shift;
    return $MetaCPAN::Role::Common::log if($MetaCPAN::Role::Common::log);
    my $app = Log::Log4perl::Appender->new(
                    "Log::Log4perl::Appender::ScreenColoredLevels",
                    stderr => 0);
                    my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %p{1} %m{chomp}%n");
    my $log = Log::Log4perl->get_logger;
    $log->level(Log::Log4perl::Level::to_priority( uc($self->level) ));
    $log->add_appender($app);
    $app->layout($layout);
    $MetaCPAN::Role::Common::log = $log;
    return $log;
}

sub file2mod {

    my $self = shift;
    my $name = shift;

    $name =~ s{\Alib\/}{};
    $name =~ s{\.(pod|pm)\z}{};
    $name =~ s{\/}{::}gxms;

    return $name;
}

sub _build_debug {

    my $self = shift;
    return $ENV{'DEBUG'} || 0;

}

sub _build_cpan {

    my $self = shift;
    my @dirs =
      ( "$ENV{'HOME'}/CPAN", "$ENV{'HOME'}/minicpan", $ENV{'MINICPAN'} );
    foreach my $dir ( grep { defined } @dirs ) {
        return $dir if -d $dir;
    }
    die
"Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN";

}

sub _build_es {

    my $e = ElasticSearch->new(
        servers   => 'localhost:9200',
        transport => 'http',             # default 'http'
        timeout   => 30,

        #trace_calls => 'log_file',
    );

}

sub run {}
before run => sub {
    my $self = shift;
    set_logger $self->logger unless($MetaCPAN::Role::Common::log);
};

1;

=pod

=head1 SYNOPSIS

Roles which should be available to all modules

=cut
