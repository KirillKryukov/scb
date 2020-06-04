#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

my ($out_path);
GetOptions(
    'out=s' => \$out_path,
)
or die "Can't parse command line arguments\n";
if (!defined $out_path) { die "Output file is not specified\n"; }

my $name = basename($out_path);
$name =~ s/\s/_/g;

my $temp_dir;
if (!defined $temp_dir and exists $ENV{'TMPDIR'}) { $temp_dir = $ENV{'TMPDIR'}; }
if (!defined $temp_dir and exists $ENV{'TEMP'}) { $temp_dir = $ENV{'TEMP'}; }
if (!defined $temp_dir and exists $ENV{'TMP'}) { $temp_dir = $ENV{'TMP'}; }
if (!defined $temp_dir) { die "Can't detect temp directory, please define TMPDIR environment variable\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.cmix-temp.fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

if (-e $out_path) { unlink $out_path; }
#if (-e "$out_path.t") { unlink "$out_path.t"; }

#my $cmd = "cmix -c '$temp_fasta' '$out_path.t' >/dev/null 2>&1";
my $cmd = "cmix -c '$temp_fasta' '$out_path' >/dev/null 2>&1";

my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

#rename "$out_path.t", $out_path;

unlink $temp_fasta;
