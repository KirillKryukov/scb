#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

my ($out, $level, $rna);
GetOptions(
    'out=s'   => \$out,
    'level=i' => \$level,
    'rna'     => \$rna,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $level) { die "Level is not specified\n"; }

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

$ENV{'TMP'} = $temp_dir;
$ENV{'TEMP'} = $temp_dir;
$ENV{'TMPDIR'} = $temp_dir;

my $inbase = basename($out);
my $temp_fasta = "$temp_dir/$inbase.fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

my $FA;
if ($rna) { open($FA, '|-', "fasta-u2t >'$temp_fasta'") or die "Can't create temporary file \"$temp_fasta\"\n"; }
else { open($FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n"; }
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

my $cmd = "MFCompressC -$level -o '$out' '$temp_fasta'";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

unlink $temp_fasta;
