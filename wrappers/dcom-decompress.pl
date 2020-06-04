#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

binmode STDOUT;

my ($in, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$temp_dir/$name.jarvis-d";
my $temp_sequence;
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";

if ($wrapper_only)
{
    $temp_sequence = $in;
}
else
{
    my $cmd = "ulimit -s unlimited; dna-compact n -d '$in' >/dev/null 2>&1";
    system($cmd);  # Successful decompression returns non-0, therefore not checking error code. 

    my $y1_path = "$in.fp.txt.y";
    if (!-e $y1_path) { die "Can't find \"$y1_path\" after: $cmd\n"; }

    $cmd = "ulimit -s unlimited; dna-compact n -d '$in.fp' >/dev/null 2>&1";
    system($cmd);  # Successful decompression returns non-0, therefore not checking error code. 

    my $y3_path = "$in.fp.y";
    if (!-e $y3_path) { die "Can't find \"$y3_path\" after: $cmd\n"; }

    $temp_sequence = $y3_path;
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");
run("zstd -dc <'$in.n' >'$temp_n'");
run("zstd -dc <'$in.iupac' >'$temp_iupac'");

my $cmd = "sequence-change-case-to-upper <'$temp_sequence'"
          . " | sequence-iupac-add --iupac '$temp_iupac'"
          . " | sequence-n-add --n '$temp_n'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
run($cmd);

if (!$wrapper_only) { unlink $temp_sequence; }
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_n;
unlink $temp_iupac;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
