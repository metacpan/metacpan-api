use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Multiple-Modules-RDeps-Deprecated",
  NAME     => "Multiple::Modules::RDeps::Deprecated",
  VERSION  => "0.01",
  ABSTRACT => 'A dist that depends on Multiple::Modules::Deprecated',
  PREREQ_PM => { 
    'Multiple::Modules::Deprecated' => '0',
  },
);
