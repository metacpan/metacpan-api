#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

my $CLASS = 'MetaCPAN::Model::Archive';
require_ok $CLASS;

subtest 'missing required arguments' => sub {
    throws_ok { $CLASS->new } qr{archive};
};

subtest 'file does not exist' => sub {
    my $file = 'hlaglhalghalghj.blah';
    my $archive = $CLASS->new( file => $file );

    throws_ok { $archive->files } qr{$file does not exist};
};

subtest 'archive extraction' => sub {
    my %want = (
        'Some-1.00-TRIAL/lib/Some.pm' => 45,
        'Some-1.00-TRIAL/Makefile.PL' => 172,
        'Some-1.00-TRIAL/t/00-nop.t'  => 41,
        'Some-1.00-TRIAL/META.json'   => 535,
        'Some-1.00-TRIAL/META.yml'    => 356,
        'Some-1.00-TRIAL/MANIFEST'    => 62,
    );

    my $archive
        = $CLASS->new( file =>
            't/var/tmp/fakecpan/authors/id/L/LO/LOCAL/Some-1.00-TRIAL.tar.gz'
        );

    ok !$archive->is_impolite;
    ok !$archive->is_naughty;

    cmp_bag $archive->files, [ keys %want ];

    my $dir = $archive->extract;
    for my $file ( keys %want ) {
        my $size = $want{$file};

        is -s $dir->file($file), $size, "size of $file";
    }
};

subtest 'temp cleanup' => sub {
    my $tempdir;

    {
        my $archive
            = $CLASS->new( file =>
                't/var/tmp/fakecpan/authors/id/L/LO/LOCAL/Some-1.00-TRIAL.tar.gz'
            );

        $tempdir = $archive->extract;
        ok -d $tempdir;

        # stringify to get rid of the temp object so $tempdir doesn't keep
        # it alive
        $tempdir = "$tempdir";
    }

    ok !-d $tempdir;
};

subtest 'extract once' => sub {
    my $archive
        = $CLASS->new( file =>
            't/var/tmp/fakecpan/authors/id/L/LO/LOCAL/Some-1.00-TRIAL.tar.gz'
        );

    is $archive->extract, $archive->extract;
};

subtest 'set extract dir' => sub {
    my $temp = File::Temp->newdir;

    {
        my $archive = $CLASS->new(
            file =>
                't/var/tmp/fakecpan/authors/id/L/LO/LOCAL/Some-1.00-TRIAL.tar.gz',
            extract_dir => $temp->dirname
        );

        my $dir = $archive->extract_dir;

        isa_ok $dir, 'Path::Class::Dir';
        is $dir,     $temp;
        is $archive->extract, $temp;
        ok -s $dir->file('Some-1.00-TRIAL/META.json');
    }

    ok -e $temp, q[Path::Class doesn't clean up directories it was handed];
};

done_testing;
