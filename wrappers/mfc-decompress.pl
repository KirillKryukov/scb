#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

my ($in, $rna);
GetOptions(
    'in=s' => \$in,
    'rna'  => \$rna,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

$ENV{'TMP'} = $temp_dir;
$ENV{'TEMP'} = $temp_dir;
$ENV{'TMPDIR'} = $temp_dir;

my $inbase = basename($in);
my $temp_fasta = "$temp_dir/$inbase.fasta";

my $cmd = "MFCompressD -o '$temp_fasta' '$in'";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

$cmd = $rna ? "fasta-t2u <'$temp_fasta'" : "cat '$temp_fasta'";
system($cmd);

unlink $temp_fasta;
