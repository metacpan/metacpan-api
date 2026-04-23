#!/usr/bin/env perl
use strict;
use warnings;

use Archive::Tar          qw( COMPRESS_GZIP );
use File::Basename        qw( basename dirname );
use File::Spec::Functions qw( abs2rel catdir rel2abs splitdir );
use File::Path            qw( mkpath );
use File::Find            ();
use File::Copy            qw( copy );
use Cwd                   qw( cwd );
use CPAN::Checksums       ();
use Getopt::Long          qw( GetOptions );
use JSON::PP              qw( decode_json );

sub is_empty_dir {
    my $dir = shift;
    return !!0
        if !-d $dir;
    opendir my $dh, $dir
        or die "can't read $dir: $!";
    my $empty = !!1;
    while ( my $entry = readdir $dh ) {
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

pod2usage( -verbose => 2, -exitval => 0 )
    if $help;

my $out = shift
    or die "output directory must be specified!\n";

!-e $out
    or is_empty_dir($out)
    or die "output directory must not exist or be empty!\n";

my $source_dir = catdir( dirname(__FILE__), 'fakecpan' );

mkpath($out);

die "couldn't create $out: $!\n"
    if !-d $out;

my %gz = (
    'authors/01mailrc.txt'           => 0,
    'authors/08pumpkings.txt'        => 0,
    'modules/02packages.details.txt' => 0,
    'modules/03modlist.data'         => 0,
    'modules/06perms.txt'            => 1,
);

File::Find::find(
    {
        no_chdir => 1,
        wanted   => sub {
            my $file = $_;
            return
                if $file eq '.';
            my $rel  = abs2rel( $file, $source_dir );
            my $dest = rel2abs( $rel, $out );
            if ( -d $file ) {
                my @parts = splitdir($rel);
                if ( $parts[0] eq 'authors' && @parts == 6 ) {
                    $File::Find::prune = 1;
                    my $archive_root_dir = $file;
                    my $dirname          = dirname($archive_root_dir);
                    my $tar_root         = basename($archive_root_dir);
                    my $options          = {};
                    my $extra = "$archive_root_dir/x_metacpan.json";
                    if ( open my $fh, '<', $extra ) {
                        my $json = do { local $/; <$fh> };
                        close $fh;
                        $options = decode_json($json);
                    }

                    if ( $options->{no_top_level} ) {
                        $tar_root = '';
                    }

                    my $tarball = "$dest.tar.gz";

                    # jan 1 2026
                    my $mtime = $options->{mtime} // 1767225600;

                    print "creating $rel.tar.gz\n" if $v;

                    my $tar = Archive::Tar->new;
                    File::Find::find(
                        {
                            no_chdir   => 1,
                            preprocess => sub { sort @_ },
                            wanted     => sub {
                                my $name = $_;
                                my $rel  = abs2rel( $_, $archive_root_dir )
                                    =~ s{\A\.(?:/|\z)}{}r;
                                return
                                    if $rel eq 'x_metacpan.json';

                                my $tar_path = join '/', grep length,
                                    $tar_root, $rel;
                                return
                                    if !length $tar_path;

                                my ($afile) = $tar->add_files($name);
                                $afile->rename($tar_path);
                                $afile->uid(0);
                                $afile->gid(0);
                                $afile->uname('root');
                                $afile->gname('root');
                                $afile->mode( oct( -x ? '0755' : '0644' ) );
                                $afile->mtime($mtime);
                            },
                        },
                        $archive_root_dir,
                    );

                    $tar->write( $tarball, COMPRESS_GZIP );

                    utime $mtime, $mtime, $tarball;
                }
                elsif ( !-e $dest ) {
                    print "creating $rel/\n" if $v;
                    mkdir $dest;
                }
            }
            else {
                print "copying $rel\n" if $v;
                copy $file, $dest;
                if ( exists $gz{$rel} ) {
                    my $keep    = $gz{$rel};
                    my @command = qw(gzip -9 -n);
                    push @command, '-k'
                        if $keep;
                    print "gzipping $rel\n" if $v;
                    system @command, $dest;
                }
            }
        },
        postprocess => sub {
            my $dir  = $File::Find::dir;
            my $rel  = abs2rel( $dir, $source_dir );
            my $dest = rel2abs( $rel, $out );
            if ( $rel =~ m{\Aauthors/id(?:\z|/)} ) {
                print "generating $rel/CHECKSUMS\n" if $v;
                CPAN::Checksums::updatedir( $dest, "$out/authors/id" );
            }
            elsif ( $rel eq 'authors' ) {
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
    },
    $source_dir
);

__END__

=head1 NAME

mk-cpan.pl - Generate a fake cpan directory

=head1 SYNOPSIS

    mk-cpan.pl [ -v ] [ -h | <output dir> ]
