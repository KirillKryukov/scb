#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);

my ($in) = @ARGV;
if (!defined $in) { die "Input file is not specified\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir;
if (!defined $temp_dir and exists $ENV{'TMPDIR'}) { $temp_dir = $ENV{'TMPDIR'}; }
if (!defined $temp_dir and exists $ENV{'TEMP'}) { $temp_dir = $ENV{'TEMP'}; }
if (!defined $temp_dir and exists $ENV{'TMP'}) { $temp_dir = $ENV{'TMP'}; }
if (!defined $temp_dir) { die "Can't detect temp directory, please define TMPDIR environment variable\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.lztd-temp.fasta";

my $cmd = "lzturbo_static -d '$in' '$temp_fasta'";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

if (!-e $temp_fasta) { exit(1); }

system("cat $temp_fasta");

unlink $temp_fasta;
