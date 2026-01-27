#!/bin/sh

# This script is only needed if you are developing metacpan,
# on the live servers we use File::Rsync::Mirror::Recent
# https://github.com/metacpan/metacpan-puppet/tree/master/modules/rrrclient

minicpan -l /home/metacpan/CPAN -r https://www.cpan.org/ --log-level=warn
