use strict;
use warnings;

requires 'perl', '5.010';

requires 'Archive::Any', '0.0946';
requires 'Archive::Tar', '2.40';
requires 'Authen::SASL', '2.16'; # for Email::Sender::Transport::SMTP
requires 'Captcha::reCAPTCHA', '0.99';
requires 'Catalyst', '5.90128';
requires 'Catalyst::Action::RenderView', '0.16';
requires 'Catalyst::Controller::REST', '1.21';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Session', '0.43';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::View::JSON', '0.37';
requires 'CatalystX::Fastly::Role::Response', '0.06';
requires 'CHI', '0.61';
requires 'Config::General', '2.63';
requires 'Config::ZOMG', '1.000000';
requires 'Const::Fast';
requires 'CPAN::DistnameInfo', '0.12';
requires 'Cpanel::JSON::XS', '4.32';
requires 'CPAN::Meta', '2.150005'; # Avoid issues with List::Util dep under carton install.
requires 'CPAN::Meta::Requirements', '2.140';
requires 'CPAN::Meta::YAML', '0.018';
requires 'CPAN::Repository::Perms';
requires 'Cwd';
requires 'Data::Dumper';
requires 'DateTime', '1.54';
requires 'DateTime::Format::ISO8601';
requires 'DBD::SQLite', '1.66';
requires 'DBI', '1.643';
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'ElasticSearchX::Model', '2.0.1';
requires 'Email::Sender::Simple';
requires 'Email::Simple';
requires 'Email::Valid', '1.203';
requires 'Encode', '3.17';
requires 'Encoding::FixLatin';
requires 'Encoding::FixLatin::XS';
requires 'EV';
requires 'Exporter', '5.74';
requires 'File::Basename';
requires 'File::Copy';
requires 'File::Find';
requires 'File::Find::Rule';
requires 'File::Find::Rule::Perl';
requires 'File::Spec';
requires 'File::Spec::Functions';
requires 'File::pushd';
requires 'File::stat';
requires 'File::Temp';
requires 'FindBin';
requires 'Getopt::Long::Descriptive', '0.103';
requires 'Gravatar::URL';
requires 'Hash::Merge::Simple';
requires 'HTML::Entities';
requires 'HTTP::Request::Common', '6.36';
requires 'IO::Prompt::Tiny';
requires 'IO::Uncompress::Bunzip2', '2.106';
requires 'IO::Zlib';
requires 'IPC::Run3', '0.048';
requires 'List::Util', '1.62';
requires 'Log::Any::Adapter';
requires 'Log::Any::Adapter::Log4perl';
requires 'Log::Contextual';
requires 'Log::Dispatch';
requires 'Log::Dispatch::Syslog';
requires 'Log::Log4perl';
requires 'Log::Log4perl::Appender::ScreenColoredLevels';
requires 'Log::Log4perl::Catalyst';
requires 'Log::Log4perl::Layout::JSON';
requires 'LWP::Protocol::https';
requires 'LWP::UserAgent', '6.66';
requires 'MetaCPAN::Moose';
requires 'MetaCPAN::Pod::HTML' => '0.004000';
requires 'MetaCPAN::Role', '0.06';
requires 'MIME::Base64', '3.15';
requires 'Minion', '9.03';
requires 'Minion::Backend::SQLite';
requires 'Module::Load';
requires 'Module::Metadata', '1.000038';
requires 'Module::Pluggable';
requires 'Module::Runtime';
requires 'Mojolicious::Plugin::MountPSGI', '0.14';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Mojolicious::Plugin::Web::Auth', '0.17';
requires 'Mojo::Pg', '4.08';
requires 'Moose', '2.2201';
requires 'MooseX::Attribute::Deflator', '2.1.5';
requires 'MooseX::Fastly::Role', '0.02';
requires 'MooseX::Getopt', '0.71';
requires 'MooseX::Getopt::Dashes';
requires 'MooseX::Getopt::OptionTypeMap';
requires 'MooseX::StrictConstructor';
requires 'MooseX::Types';
requires 'MooseX::Types::ElasticSearch', '0.0.4';
requires 'MooseX::Types::Moose';
requires 'Mozilla::CA', '20211001';
requires 'namespace::autoclean';
requires 'Net::Fastly', '1.12';
requires 'Net::GitHub::V4';
requires 'Parse::CPAN::Packages::Fast', '0.09';
requires 'Parse::PMFile', '0.43';
requires 'Path::Iterator::Rule', '>=1.011';
requires 'PAUSE::Permissions', '0.17';
requires 'PerlIO::gzip';
requires 'Plack', '1.0048';
requires 'Plack::App::Directory';
requires 'Plack::Middleware::ReverseProxy';
requires 'Plack::Middleware::Session';
requires 'Plack::Session::Store';
requires 'Pod::Markdown', '3.300';
requires 'Pod::Simple', '3.43';
requires 'Pod::Simple::XHTML', '3.24';
requires 'Pod::Text', '4.14';
requires 'Ref::Util';
requires 'Safe', '2.35'; # bug fixes (used by Parse::PMFile)
requires 'Scalar::Util', '1.62'; # Moose
requires 'Search::Elasticsearch' => '8.12';
requires 'Search::Elasticsearch::Client::2_0' => '6.81';
requires 'Term::Choose', '1.754'; # Git::Helpers
requires 'Throwable::Error';
requires 'Term::Size::Any'; # for Catalyst
requires 'Text::CSV_XS';
requires 'Try::Tiny', '0.30';
requires 'Type::Tiny', '2.000001';
requires 'Types::Path::Tiny';
requires 'Types::URI';
requires 'Twitter::API', '1.0006';
requires 'URI', '5.10';
requires 'version', '0.9929';
requires 'XML::XPath';
requires 'YAML::XS', '0.83'; # Mojolicious::Plugin::OpenAPI YAML loading

# test requirements
requires 'Code::TidyAll', '0.82';
requires 'Code::TidyAll::Plugin::UniqueLines';
requires 'CPAN::Faker', '0.011';
requires 'Devel::Confess';
requires 'HTTP::Cookies', '6.10';
requires 'MetaCPAN::Client', '2.029000';
requires 'Module::Faker', '== 0.017';
requires 'Module::Faker::Dist', '== 0.017';
requires 'OrePAN2', '0.48';
requires 'Parallel::ForkManager' => '2.02';
requires 'Perl::Critic', '0.140';
requires 'Perl::Tidy' => '== 20240511';
requires 'PPI', '1.274'; # Perl::Critic
requires 'PPIx::QuoteLike', '0.022'; # Perl::Critic
requires 'PPIx::Regexp', '0.085'; # Perl::Critic
requires 'String::Format', '1.18'; # Perl::Critic
requires 'Test::Deep';
requires 'Test::Fatal';
requires 'Test::Harness', '3.44'; # Contains App::Prove
requires 'Test::More', '1.302190';
requires 'Test::Perl::Critic', '1.04';
requires 'Test::RequiresInternet';
requires 'Test::Routine', '0.012';
requires 'Test::Vars', '0.015';

# author requirements
requires 'App::perlimports';
