use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME => "Prereqs-Basic",
  NAME     => "Prereqs::Basic",
  VERSION  => "0.01",
  ABSTRACT => 'A perl module with prereqs',
  PREREQ_PM => { 
    'For::Build::Requires1' => '2.45',
    'For::Runtime::Requires1' => '0',
    'For::Runtime::Requires2' => '1.23',
  },
);
