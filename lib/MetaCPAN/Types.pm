package MetaCPAN::Types;
use ElasticSearch;

use MooseX::Types -declare => [
    qw(
      ES
      Logger
      ) ];

use MooseX::Types::Moose qw/Int Str ArrayRef HashRef/;

class_type Logger, { class => 'Log::Log4perl::Logger' };
coerce Logger, from ArrayRef, via {
    return MetaCPAN::Role::Common::_build_logger($_);
};

class_type ES, { class => 'ElasticSearch' };
coerce ES, from Str, via {
    my $server = $_;
    $server = "127.0.0.1$server" if ( $server =~ /^:/ );
    return
      ElasticSearch->new( servers   => $server,
                          transport => 'http',
                          timeout   => 30, );
};

coerce ES, from HashRef, via {
    return ElasticSearch->new(%$_);
};

coerce ES, from ArrayRef, via {
    my @servers = @$_;
    @servers = map { /^:/ ? "127.0.0.1$_" : $_ } @servers;
    return
      ElasticSearch->new( servers   => \@servers,
                          transport => 'http',
                          timeout   => 30, );
};

1;
