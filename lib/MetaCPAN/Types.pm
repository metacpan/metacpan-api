package MetaCPAN::Types;
use ElasticSearch;

use MooseX::Types -declare => [
    qw(
      ES
      Logger
      Resources
      Stat
      ) ];

use MooseX::Types::Structured qw(Dict Tuple Optional);
use MooseX::Types::Moose qw/Int Str ArrayRef HashRef Undef/;

subtype Stat, as Dict [ mode => Int, uid => Int, gid => Int, size => Int, mtime => Int ];

subtype Resources,
  as Dict [
        license => Optional [ ArrayRef [Str] ],
        homepage => Optional [Str],
        bugtracker =>
          Optional [ Dict [ web => Optional [Str], mailto => Optional [Str] ] ],
        repository => Optional [
                                 Dict [ url  => Optional [Str],
                                        web  => Optional [Str],
                                        type => Optional [Str] ] ] ];

coerce Resources, from HashRef, via {
    my $r = $_;
    return {
          map { $_ => $r->{$_} }
          grep { defined $r->{$_} } qw(license homepage bugtracker repository)
    };
};

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
