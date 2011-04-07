package MetaCPAN::Types;
use ElasticSearch;
use MetaCPAN::Document::Module;

use MooseX::Types -declare => [
    qw(
      Logger
      Resources
      Stat
      Module
      ) ];

use MooseX::Types::Structured qw(Dict Tuple Optional);
use MooseX::Types::Moose qw/Int Num Str ArrayRef HashRef Undef/;
use ElasticSearchX::Model::Document::Types qw(:all);

subtype Stat, as Dict [ mode => Int, uid => Int, gid => Int, size => Int, mtime => Int ];

subtype Module, as ArrayRef [ Type [ 'MetaCPAN::Document::Module' ] ];
coerce Module, from ArrayRef, via { [ map { ref $_ eq 'HASH' ? MetaCPAN::Document::Module->new($_) : $_ } @$_ ] };
coerce Module, from HashRef, via { [ MetaCPAN::Document::Module->new($_) ] };

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

1;
