####conf/author.json

conf/author-2.0.json is now a sample file. Please use this as a reference for
fields you may want to add to your author-2.0.json file

Please upload the author-2.0.json file to the root directory of your PAUSE 
directory. We are going to index these files once a day. Since you cannot
overwrite files, you need to supply a new version number when you do
changes. Please remove the old file to reduce the inode load on the CPAN
mirrors.

conf/author-2.0.json is a mashup of fields added by different authors. 
If you wish to add new fields please contact us. The "extra" field can
be used to store an arbitrary object. It is being serialized and then
stored in the backend and is available for full-text search.