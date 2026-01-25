use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "No-Packages",
  NAME     => "No::Packages",
  VERSION  => "1.1",
  ABSTRACT => 'An archive with pm files but no parseable packages',
  PREREQ_PM => { 
  },
);
