# Indexing

## How to index a release

On the VM:

    sh /home/vagrant/bin/metacpan-api-carton-exec bin/metacpan release /home/vagrant/CPAN/authors/id --latest

## Field states

_Releases_ contain many _Files_, which contain many _Modules_, which are really
Perl package definitions.  Both Modules and Files have the flags `authorized`
and `indexed`.

Refer to MetaCPAN::Document::File and MetaCPAN::Document::Module for the code
described here, and some additional discussion in POD.


### module.authorized

Defaults to true.  Set to false (by File's `set_authorized`) if all of the
following are true:

* The distribution name is not "perl"

* The Module appears in 06perms

* The File's author doesn't have permissions for the Module


### file.authorized

Defaults to true.  Set to false (by File's `set_authorized`) if all the
following are true:

* The distribution name is not "perl"

* A package name is set in file.documentation (either from a pod NAME section
  or the first module)

* The documentation package is in 06perms

* The File's author doesn't have permissions for the documentation package


### file.indexed and module.indexed

file.indexed defaults to false if one of the following is true:

* The File's path is in a static list of unindexed files (Makefile.PL, Changes,
  INSTALL, etc)

* The Release's META file states the File shouldn't be indexed

Otherwise, file.indexed defaults to true.  module.indexed defaults to true.

Then, the following rules in File's `set_indexed` are followed when processing
the archive in MetaCPAN::Script::Release:

* If a Module of the File is listed in the Release's META "provides" and is at
  the correct path, the Module is marked as indexed.  **The first Module marked
  as provides in META short-circuits the rest of the loop and the other Modules
  and parent File are _not_ updated.**  This means they get the default.

* If the File is in a static list of unindexed files (Makefile.PL, Changes,
  INSTALL, etc), the File and all Modules under it have indexed set to false.
  (Yes, this is the same special-casing in the default code noted above.) 

* If the File is under a "no index" directory in the Release's META,
  file.indexed is set to false.  **Modules are _not_ updated.**

* If the Module name doesn't start with an ASCII letter or the
  Release's META file says the package shouldn't be indexed, then
  module.indexed is set to false.

* If the Module's package definition uses the "hide from PAUSE" trick, then
  module.indexed is set to false.  Otherwise, module.indexed is set to true.

* The File has a documentation name, then file.indexed is set to true if there
  are no Modules (packages) and false if there _are_ Modules and none of them
  match the documentation name.


### file.documentation

A string, expected to be a package name (or maybe a script name), for which the
file ostensibly provides documentation.  It is also sometimes used conceptually
as the "primary Module" of the File.

If the file is a .pod file, the string parsed from the `NAME` section is
returned.

If the file is any other Perl file, then the returned value is:

* The package parsed from the `NAME` section if it matches an _indexed_ Module
* Otherwise, the first _indexed_ Module
* Otherwise, the string parsed from the `NAME` section
* Finally, the first Module


### release.authorized

Defaults to true.  Set to false by MetaCPAN::Script::Release if any of the
Modules (via Files) in the Release are marked unauthorized but indexed.



## Notes on timing/ordering

* `Document::File->set_indexed` **must** be called as early as possible,
  otherwise things which inspect file.indexed or module.indexed will get
  default values for those fields not _real_ values.

* Similarly, `Document::File->set_authorized` should be called as soon after
  `set_indexed` as possible.



## Use cases to support

Installing a package, various ways:

    cpanm Moose
    cpanm Moose@2.1806
    cpanm Moose~'>2, <3'
    cpanm --dev Moose
    cpanm --dev Moose~'>2, <3'  # maybe not?

May need to inspect:

    release.authorized
    release.status
    file.indexed
    file.authorized
    file.status
    module.indexed
    module.authorized
