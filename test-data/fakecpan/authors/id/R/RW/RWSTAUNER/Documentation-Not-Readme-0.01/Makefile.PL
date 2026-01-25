use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Documentation-Not-Readme",
  NAME     => "Documentation::Not::Readme",
  VERSION  => "0.01",
  ABSTRACT => 'A dist with a README.pod that should *not* be considered the main module documentation.',
  PREREQ_PM => { 
  },
);
