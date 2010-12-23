####conf/author.json

conf/author.json is now a sample file. Please use this as a reference for
fields you may want to add to your author.json file

Author files are now in a directory structure which is the same as your CPAN
author directory (thanks to BDFOY) For example, you'll find BDFOY in
conf/authors/B/BD/BDFOY/author.json

conf/author.json is a mashup of fields added by different authors. If you add
a new field to your own author.json file, please also add it to
conf/author.json so it's easier for everyone to find. Use ARRAYs where you
feel it's appropriate.

For a current list of all fields used by other authors, have a look at
conf/USEDFIELDS.txt  You can also update this file:

perl bin/get_fields.pl > conf/USEDFIELDS.txt

Once you've completed your own author file, please check your syntax. :)

perl bin/check_json.pl conf/authors/B/BD/BDFOY/author.json
