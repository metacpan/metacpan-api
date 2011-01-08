#!/bin/sh

perl delete_index.pl cpan
perl create_index.pl cpan
perl put_mappings.pl
perl index_authors.pl
perl index_cpanratings.pl
perl index_dists.pl --refresh_db
#cd /home/cpan/elasticsearch && zip -r /home/cpan/data_snapshot.zip data
