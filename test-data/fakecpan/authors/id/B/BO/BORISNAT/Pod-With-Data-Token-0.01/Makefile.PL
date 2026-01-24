use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Pod-With-Data-Token",
  NAME     => "Pod::With::Data::Token",
  VERSION  => "0.01",
  ABSTRACT => 'Include a __DATA__ token inside a pod block',
  PREREQ_PM => { 
  },
);
