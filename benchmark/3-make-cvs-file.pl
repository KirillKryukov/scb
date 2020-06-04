#!/usr/bin/env perl
#
# 3-make-cvs-file.pl
# by Kirill Kryukov, 2020, public domain
#

use strict;
use File::Basename qw(basename);
use File::Glob qw(:bsd_glob);
use File::Slurp;
use Sort::Versions;

my $out_file = 'results.csv';
open (my $OUT, '>', $out_file) or die;
binmode $OUT;

print $OUT '#dataset name,uncompressed size,setting name,compressed size';
for (my $i = 1; $i <= 10; $i++) { print $OUT ",compression time $i"; }
for (my $i = 1; $i <= 10; $i++) { print $OUT ",decompression time $i"; }
for (my $i = 1; $i <= 10; $i++) { print $OUT ",compression memory $i"; }
for (my $i = 1; $i <= 10; $i++) { print $OUT ",decompression memory $i"; }
print $OUT "\n";

foreach my $dir (bsd_glob('3-results/*'))
{
    if (!-d $dir) { next; }
    my $dataset_name = substr(basename($dir), 4);
    chomp(my $uncompressed_size = read_file("$dir/size"));
    my @files = bsd_glob("$dir/*");
    foreach my $file (sort { versioncmp($a, $b) } @files)
    {
        my $setting_name = basename($file);
        if ($setting_name eq 'size') { next; }

        chomp(my @lines = read_file($file));
        my $compressed_size = $lines[0];
        my @ctimes = split(' ', $lines[1]);
        my @dtimes = split(' ', $lines[2]);
        my @cmems = split(' ', $lines[3]);
        my @dmems = split(' ', $lines[4]);
        if (scalar(@ctimes) < 10) { push @ctimes, ('') x (10 - scalar(@ctimes)); }
        if (scalar(@dtimes) < 10) { push @dtimes, ('') x (10 - scalar(@dtimes)); }
        if (scalar(@cmems) < 10) { push @cmems, ('') x (10 - scalar(@cmems)); }
        if (scalar(@dmems) < 10) { push @dmems, ('') x (10 - scalar(@dmems)); }

        print $OUT "$dataset_name,$uncompressed_size,$setting_name,$compressed_size";
        print $OUT ',', join(',', @ctimes);
        print $OUT ',', join(',', @dtimes);
        print $OUT ',', join(',', @cmems);
        print $OUT ',', join(',', @dmems);
        print $OUT "\n";
    }
}

close $OUT;
