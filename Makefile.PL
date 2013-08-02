use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30 qw( WriteMakefile );

my %WriteMakefileArgs = (
  ABSTRACT => "A free, open API for everything you want to know about CPAN",
  AUTHOR => 'Moritz Onken <onken@netcubed.de>, Olaf Alders <olaf@wundercounter.com>',

  # modules required for testing
  BUILD_REQUIRES => {
    "App::Prove" => 0,
    "CPAN::Faker" => "0.009",
    "Module::Faker" => "0.010",
    "Module::Faker::Dist" => "0.010",
    "Config::General" => 0,
    "ElasticSearch::TestServer" => 0,
    "File::Copy" => 0,
    "Test::Aggregate::Nested" => "0.366",
    "Test::More" => "0.96",
    "Test::Most" => 0,
  },

  CONFIGURE_REQUIRES => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  DISTNAME => "MetaCPAN",
  LICENSE => "bsd",
  MIN_PERL_VERSION => "5.010",
  NAME => "MetaCPAN",

  # runtime dependencies
  PREREQ_PM => {
    "Archive::Any" => 0,
    "Archive::Any::Plugin" => 0,
    "Archive::Tar" => 0,
    "CHI" => 0,
    "CPAN::DistnameInfo" => 0,
    "CPAN::Meta" => 0,
    "CPAN::Meta::Requirements" => 0,
    "Captcha::reCAPTCHA" => "0.94",
    "Catalyst" => "5.90011",
    "Catalyst::Action::RenderView" => 0,
    "Catalyst::Authentication::User" => 0,
    "Catalyst::Controller" => 0,
    "Catalyst::Controller::REST" => "0.94",
    "Catalyst::Model" => 0,
    "Catalyst::Plugin::Authentication" => 0,
    "Catalyst::Plugin::ConfigLoader" => 0,
    "Catalyst::Plugin::Session" => 0,
    "Catalyst::Plugin::Session::State::Cookie" => 0,
    "Catalyst::Plugin::Session::Store" => 0,
    "Catalyst::Plugin::Static::Simple" => 0,
    "Catalyst::Plugin::Unicode::Encoding" => 0,
    "Catalyst::Utils" => 0,
    "Catalyst::View" => 0,
    "Catalyst::View::JSON" => 0,
    "CatalystX::Component::Traits" => 0,
    "CatalystX::InjectComponent" => 0,
    "CatalystX::RoleApplicator" => 0,
    "Class::MOP" => 0,
    "Config::JFDI" => 0,
    "Cwd" => 0,
    "DBD::SQLite" => "1.33",
    "DBI" => "1.616",
    "Data::DPath" => 0,
    "Data::Dump" => 0,
    "Data::Dumper" => 0,
    "DateTime" => 0,
    "DateTime::Format::ISO8601" => 0,
    "Devel::ArgNames" => 0,
    "Digest::MD5" => 0,
    "Digest::SHA1" => 0,
    "EV" => 0,
    "ElasticSearch" => "0.65",
    "ElasticSearchX::Model" => "0.1.5",
    "ElasticSearchX::Model::Document" => 0,
    "ElasticSearchX::Model::Document::Set" => 0,
    "ElasticSearchX::Model::Document::Types" => 0,
    "ElasticSearchX::Model::Util" => 0,
    "ExtUtils::MakeMaker" => "6.30",
    "Email::Address" => 0,
    "Email::Sender::Simple" => 0,
    "Email::Simple" => 0,
    "Email::Valid" => 0,
    "Encode" => 0,
    "Encoding::FixLatin" => 0,
    "Exporter" => 0,
    "Facebook::Graph" => 0,
    "File::Basename" => 0,
    "File::Find" => 0,
    "File::Find::Rule" => 0,
    "File::Find::Rule::Perl" => 0,
    "File::Spec" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "File::stat" => 0,
    "Find::Lib" => 0,
    "FindBin" => 0,
    "Graph::Centrality::Pagerank" => 0,
    "Gravatar::URL" => 0,
    "HTML::TokeParser::Simple" => 0,
    "HTTP::Request::Common" => 0,
    "Hash::Merge::Simple" => 0,
    "IO::All" => 0,
    "IO::Interactive" => 0,
    "IO::String" => 0,
    "IO::Uncompress::Bunzip2" => 0,
    "IO::Zlib" => 0,
    "IPC::Run3" => 0,
    "JSON" => 2,
    "JSON::Any" => 0,
    "JSON::XS" => 0,
    "LWP::Protocol::https" => 0,
    "LWP::UserAgent" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => 0,
    "Log::Contextual" => 0,
    "Log::Log4perl" => 0,
    "Log::Log4perl::Appender::ScreenColoredLevels" => 0,
    "Module::Metadata" => 0,
    "Module::Pluggable" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Moose::Util" => 0,
    "MooseX::Aliases" => 0,
    "MooseX::Attribute::Deflator" => "2.1.5",
    "MooseX::ChainedAccessors" => 0,
    "MooseX::Getopt" => 0,
    "MooseX::Getopt::OptionTypeMap" => 0,
    "MooseX::Types" => 0,
    "MooseX::Types::Common::String" => 0,
    "MooseX::Types::ElasticSearch" => 0,
    "MooseX::Types::Moose" => 0,
    "MooseX::Types::Path::Class" => 0,
    "MooseX::Types::Structured" => 0,
    "Mozilla::CA" => 0,
    "Net::Twitter" => 0,
    "Parse::CPAN::Packages::Fast" => "0.04",
    "Parse::CSV" => 0,
    "Path::Class" => 0,
    "Path::Class::File" => 0,
    "Perl::PrereqScanner" => "1.014",
    "PerlIO::gzip" => 0,
    "Pithub" => 0,
    "Plack::App::Directory" => 0,
    "Plack::MIME" => 0,
    "Plack::Middleware::Header" => 0,
    "Plack::Middleware::ReverseProxy" => 0,
    "Plack::Middleware::ServerStatus::Lite" => 0,
    "Plack::Middleware::Session" => 0,
    "Plack::Session::Store" => 0,
    "Plack::Test" => 0,
    "Plack::Util::Accessor" => 0,
    "Pod::Coverage::Moose" => "0.02",
    "Pod::Markdown" => 0,
    "Pod::POM" => 0,
    "Pod::Simple::XHTML" => "3.24",
    "Pod::Text" => 0,
    "Regexp::Common" => 0,
    "Regexp::Common::time" => 0,
    "Starman" => 0,
    "Test::More" => 0,
    "Time::Local" => 0,
    "Throwable::Error" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "URI::Escape" => 0,
    "WWW::Mechanize" => 0,
    "WWW::Mechanize::Cached" => 0,
    "XML::Simple" => 0,
    "YAML" => 0,
    "YAML::Syck" => 0,
    "base" => 0,
    "feature" => 0,
    "namespace::autoclean" => 0,
    "strict" => 0,
    "strictures" => 1,
    "utf8" => 0,
    "version" => '0.9901',
    "warnings" => 0,
  },

  # We don't need 'make' or 'make install' but cpanm won't find deps
  # from WriteEmptyMakefile.  To avoid unnecessary bulding (pm_to_blib, etc)
  # we supply our own 'test' in the postamble.
  SKIP => [qw( all test install )],

  VERSION => "0.0.1",

  test => {
    # t/fakecpan.t uses Test::Aggregate to run most of the other tests
    "TESTS" => "t/*.t"
  }
);


# backward compatibility with older EUMM's
unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# stuff to append to the Makefile
sub MY::postamble {
  return <<POST

# let install exist but make it a no-op
# that way 'cpanm .' appears successful
install:

# the tests should not recurse, t/fakecpan.t does that with Test::Aggregate
test :
\t prove -lv t/

POST
}

1;
