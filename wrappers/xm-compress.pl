#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $hashSize, $context, $limit, $threshold, $chance, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'hashSize=s'   => \$hashSize,
    'context=s'    => \$context,
    'limit=s'      => \$limit,
    'threshold=s'  => \$threshold,
    'chance=s'     => \$chance,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $hashSize) { die "hashSize is not specified\n"; }
if (!defined $context) { die "context is not specified\n"; }
if (!defined $limit) { die "limit is not specified\n"; }
if (!defined $threshold) { die "threshold is not specified\n"; }
if (!defined $chance) { die "chance is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name.xm-c";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_sequence  = "$temp_prefix-seq";
my $temp_fasta_2   = "$temp_prefix-fa2";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

open(my $P, '>', "$out.parameters") or die;
binmode $P;
print $P "$hashSize $context $limit $threshold $chance";
close $P;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

open(my $T, '>', $temp_fasta_2) or die "Can't create \"$temp_fasta_2\"\n";
binmode $T;
print $T ">\n";
close $T;

my $cmd = "fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta'"
          . " | sequence-soft-mask-remove --mask '$temp_soft_mask'"
          . " | sequence-n-remove --n '$temp_n'"
          . " | sequence-iupac-remove --iupac '$temp_iupac'"
          . ' | sequence-split-to-lines --line-length 80'
          . " >'$temp_sequence'";
run($cmd);

run("cat '$temp_sequence' >>'$temp_fasta_2'");

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");
run("zstd -c -1 <'$temp_soft_mask' >'$out.soft-mask'");
run("zstd -c -1 <'$temp_n' >'$out.n'");
run("zstd -c -1 <'$temp_iupac' >'$out.iupac'");

if ($wrapper_only)
{
    move($temp_fasta_2, $out);
}
else
{
    run("jsa.xm.compress"
        . " --hashSize=$hashSize --context=$context --limit=$limit --threshold=$threshold --chance=$chance"
        . " --real='$out' '$temp_fasta_2' >/dev/null 2>&1");
    unlink $temp_fasta_2;
}

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_n;
unlink $temp_iupac;
unlink $temp_sequence;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
