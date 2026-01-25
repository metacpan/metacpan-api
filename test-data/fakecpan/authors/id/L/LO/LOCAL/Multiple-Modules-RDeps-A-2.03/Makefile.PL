use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Multiple-Modules-RDeps-A",
  NAME     => "Multiple::Modules::RDeps::A",
  VERSION  => "2.03",
  ABSTRACT => 'A dist that depends on Multiple::Modules::A',
  PREREQ_PM => { 
    'Multiple::Modules::A' => '0',
  },
);
