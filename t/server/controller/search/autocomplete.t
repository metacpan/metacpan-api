use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

test_psgi app, sub {
  my $cb = shift;

  # test ES script using doc['blah'] value
  {
    ok( my $res = $cb->( GET '/search/autocomplete?q=Multiple::Modu' ), 'GET' );
    ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

    is_deeply
      [ map { $_->{fields}{documentation} } @{ $json->{hits}{hits} } ],
      [qw(
        Multiple::Modules
        Multiple::Modules::A
        Multiple::Modules::B
        Multiple::Modules::RDeps
        Multiple::Modules::Tester
        Multiple::Modules::RDeps::A
        Multiple::Modules::RDeps::Deprecated
      )],
      'results are sorted by module name length'
        or diag explain $json;
  }
};

done_testing;
