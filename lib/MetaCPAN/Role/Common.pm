package MetaCPAN::Role::Common;

use Moose::Role;
use ElasticSearch;
use Log::Contextual qw( set_logger :dlog );
use Log::Log4perl ':easy';
use MetaCPAN::Types qw(:all);
use ElasticSearchX::Model::Document::Types qw(:all);
use MetaCPAN::Model;

has 'cpan' => ( is         => 'rw',
                isa        => 'Str',
                lazy_build => 1, );

has level => ( is => 'ro', isa => 'Str', required => 1, trigger => \&set_level );

has es => ( isa => ES, is => 'ro', required => 1, coerce => 1 );

has model => ( lazy_build => 1, is => 'ro' );

has port => ( isa => 'Int', is => 'ro', required => 1 );

has logger => ( is => 'ro', required => 1, isa => Logger, coerce => 1, predicate => 'has_logger' );

sub set_level {
    my $self = shift;
    $self->logger->level( Log::Log4perl::Level::to_priority( uc( $self->level ) ) );
}

sub _build_model {
    my $self = shift;
    return MetaCPAN::Model->new( es => $self->es );
}

# NOT A MOOSE BUILDER
sub _build_logger {
    my ( $config ) = @_;
    my $log = Log::Log4perl->get_logger($ARGV[0]);
    foreach my $c (@$config) {
        my $layout =
          Log::Log4perl::Layout::PatternLayout->new( delete $c->{layout}
                                                    || "%d %p{1} %c: %m{chomp}%n" );
        my $app = Log::Log4perl::Appender->new( delete $c->{class}, %$c );
        $app->layout($layout);
        $log->add_appender($app);
    }
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

sub remote {
    shift->es->transport->default_servers->[0];
}

sub run { }
before run => sub {
    my $self = shift;
    unless($MetaCPAN::Role::Common::log) {
        $MetaCPAN::Role::Common::log = $self->logger;
        set_logger $self->logger;
    }
    Dlog_debug { "Connected to $_" } $self->remote;
};

1;

=pod

=head1 SYNOPSIS

Roles which should be available to all modules

=cut
