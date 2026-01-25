use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "BadPod",
  NAME     => "BadPod",
  VERSION  => "0.01",
  ABSTRACT => 'Distribution with malformed POD',
  PREREQ_PM => { 
  },
);
