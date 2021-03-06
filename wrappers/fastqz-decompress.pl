#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

binmode STDOUT;

my ($in, $mode, $rna, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'mode=s'       => \$mode,
    'rna'          => \$rna,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }
if (!defined $mode) { die "Mode is not specified\n"; }
if ($mode ne 'fast' and $mode ne 'slow') { die "Unknown mode\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$temp_dir/$name.fastqz-d";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_seq       = "$temp_prefix-seq";

if ($wrapper_only)
{
    run("fastq-to-sequence <'$in' >'$temp_seq'");
}
else
{
    my $temp_fastq = "$temp_prefix-temp-fastq";
    my $m = ($mode eq 'slow') ? 'd' : 'f';
    run("fastqz $m '$in' '$temp_fastq' >/dev/null 2>&1");
    run("fastq-to-sequence <'$temp_fastq' >'$temp_seq'");
    unlink $temp_fastq;
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");
run("zstd -dc <'$in.n' >'$temp_n'");
run("zstd -dc <'$in.iupac' >'$temp_iupac'");

my $cmd = "cat '$temp_seq' '$in.tail'"
#          . ' | sequence-merge-to-one-line'
          . ($rna ? ' | sequence-t2u' : '')
          . " | sequence-iupac-add --iupac '$temp_iupac'"
          . " | sequence-n-add --n '$temp_n'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
system($cmd);

unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_n;
unlink $temp_iupac;
unlink $temp_seq;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
