use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Multiple-Modules-Tester",
  NAME     => "Multiple::Modules::Tester",
  VERSION  => "0.96",
  ABSTRACT => 'A dist that Multiple::Modules::* can use for testing',
  PREREQ_PM => { 
  },
);
