#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catdir catfile abs2rel rel2abs splitdir);
use File::Path qw(mkpath);
use File::Find ();
use File::Copy qw(copy);
use Cwd qw(cwd);
use CPAN::Checksums ();
use Getopt::Long qw(:config gnu_getopt);
use JSON::PP qw(decode_json);

sub is_empty_dir {
    my $dir = shift;
    return !!0
        if !-d $dir;
    opendir my $dh, $dir
        or die "can't read $dir: $!";
    my $empty = !!1;
    while (my $entry = readdir $dh) {
        next
            if $entry eq '.' || $entry eq '..';
        $empty = !!0;
        last;
    }
    return $empty;
}

GetOptions(
    'v|verbose' => \my $v,
    'h|help'    => \my $help,
) or die "Invalid options!\n";

pod2usage(-verbose => 2, -exitval => 0)
    if $help;

my $out = shift
    or die "output directory must be specified!\n";

!-e $out or is_empty_dir($out)
    or die "output directory must not exist or be empty!\n";

my $source_dir = catdir(dirname(__FILE__), 'fakecpan');

mkpath($out);

die "couldn't create $out: $!\n"
    if !-d $out;

my %gz = (
    'authors/01mailrc.txt'              => 0,
    'authors/08pumpkings.txt'           => 0,
    'modules/02packages.details.txt'    => 0,
    'modules/03modlist.data'            => 0,
    'modules/06perms.txt'               => 1,
);

File::Find::find({
    no_chdir => 1,
    wanted => sub {
        my $file = $_;
        return
            if $file eq '.';
        my $rel = abs2rel($file, $source_dir);
        my $dest = rel2abs($rel, $out);
        if (-d $file) {
            my @parts = splitdir($rel);
            if ($parts[0] eq 'authors' && @parts == 6) {
                my $dirname = dirname($file);
                my $basename = basename($file);
                my $options = {};
                my $extra = "$file/x_metacpan.json";
                if (open my $fh, '<', $extra) {
                    my $json = do { local $/; <$fh> };
                    close $fh;
                    $options = decode_json($json);
                }

                if ($options->{no_top_level}) {
                    $dirname = $file;
                    $basename = '.';
                }

                my $tarball = "$dest.tar.gz";
                print "creating $rel.tar.gz\n" if $v;
                system qw(tar -c -z),
                    '--format'  => 'ustar',
                    '--exclude' => 'x_metacpan.json',
                    '-C'        => $dirname,
                    '-f'        => $tarball,
                    $basename;

                if (my $mtime = $options->{mtime}) {
                    utime $mtime, $mtime, $tarball;
                }

                $File::Find::prune = 1;
            }
            elsif (!-e $dest) {
                print "creating $rel/\n" if $v;
                mkdir $dest;
            }
        }
        else {
            print "copying $rel\n" if $v;
            copy $file, $dest;
            if (exists $gz{$rel}) {
                my $keep = $gz{$rel};
                my @command = qw(gzip -9 -n);
                push @command, '-k'
                    if $keep;
                print "gzipping $rel\n" if $v;
                system @command, $dest;
            }
        }
    },
    postprocess => sub {
        my $dir = $File::Find::dir;
        my $rel = abs2rel($dir, $source_dir);
        my $dest = rel2abs($rel, $out);
        if ($rel =~ m{\Aauthors/id(?:\z|/)}) {
            print "generating $rel/CHECKSUMS\n" if $v;
            CPAN::Checksums::updatedir($dest, "$out/authors/id");
        }
        elsif ($rel eq 'authors') {
            my $cwd = cwd;
            chdir $out;
            mkdir 'indices';
            my $out_file = 'indices/find-ls';
            print "generating $out_file\n" if $v;
            open my $in, '-|:raw', 'find', 'authors', '-ls'
                or die "can't run find: $!";
            open my $out, '>:raw', $out_file
                or die "can't write $out_file: $!\n";
            copy $in, $out;
            close $in;
            close $out;
            print "gzipping $out_file\n" if $v;
            system qw(gzip -9 -n), $out_file;
            chdir $cwd;
        }
    },
}, $source_dir);

__END__

=head1 NAME

mk-cpan.pl - Generate a fake cpan directory

=head1 SYNOPSIS

    mk-cpan.pl [ -v ] [ -h | <output dir> ]
