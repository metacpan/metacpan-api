# This script is only needed if you are developing metacpan,
# on the live servers we use File::Rsync::Mirror::Recent 
# https://github.com/metacpan/metacpan-puppet/tree/master/modules/rrrclient

use CPAN::Mini;
 
CPAN::Mini->update_mirror(
  remote => 'http://www.cpan.org/',
  local  => "/home/metacpan/CPAN",
  log_level => 'warn',
);
