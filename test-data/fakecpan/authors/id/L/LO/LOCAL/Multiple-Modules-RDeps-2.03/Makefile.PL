use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Multiple-Modules-RDeps",
  NAME     => "Multiple::Modules::RDeps",
  VERSION  => "2.03",
  ABSTRACT => 'A dist that depends on Multiple::Modules',
  PREREQ_PM => { 
    'Multiple::Modules' => '0',
  },
);
