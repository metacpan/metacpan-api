use strict;
use warnings;
use lib 't/lib';

use Test::More;

use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Mapping;

my $config = MetaCPAN::Script::Runner::build_config;

subtest 'create, delete index' => sub {
    subtest 'create index' => sub {
        my $smockindexjson = q({
          "mock_index": {
	    "properties": {
	      "mock_field": {
		"type": "string",
		"index": "not_analyzed",
		"ignore_above": 2048
              }
	    }
          }
	});
        local @ARGV = (
            'mapping',    '--create_index',
            'mock_index', '--patch_mapping',
            $smockindexjson
        );
        my $mapping = MetaCPAN::Script::Mapping->new_with_options($config);

        ok( $mapping->run, "creation 'mock_index' succeeds" );
        is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
    };
    subtest 'info shows new index' => sub {
        local @ARGV = ( 'mapping', '--show_cluster_info' );
        my $mapping = MetaCPAN::Script::Mapping->new_with_options($config);

        ok( $mapping->run, "show info succeeds" );
        is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );

        ok( defined $mapping->indices_info, 'Index Info built' );
        ok( defined $mapping->indices_info->{'mock_index'},
            'Created Index printed' );
    };
    subtest 'delete index' => sub {
        local @ARGV = ( 'mapping', '--delete_index', 'mock_index' );
        my $mapping = MetaCPAN::Script::Mapping->new_with_options($config);

        ok( $mapping->run, "deletion 'mock_index' succeeds" );
        is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
    };
    subtest 'info does not show deleted index' => sub {
        local @ARGV = ( 'mapping', '--show_cluster_info' );
        my $mapping = MetaCPAN::Script::Mapping->new_with_options($config);

        ok( $mapping->run, "show info succeeds" );
        is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );

        ok( defined $mapping->indices_info, 'Index Info printed' );
        ok( !defined $mapping->indices_info->{'mock_index'},
            'Deleted Index not printed' );
    };
};

done_testing();
