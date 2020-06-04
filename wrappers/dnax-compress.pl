#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $preset, $params, $rna, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'preset=s'     => \$preset,
    'params=s'     => \$params,
    'rna'          => \$rna,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my %preset_params = (
    '0' => '-c2 -b20 -e4 -r4',
    '1' => '-c1 -b20 -s0',
    '2' => '-c7 -b20 -s0 -o2',
    '3' => '-c7 -b20 -s0 -o3'
);

if (defined $preset)
{
    if (defined $params) { die "--preset and --params should not be used together\n"; }
    if (exists $preset_params{$preset}) { $params = $preset_params{$preset}; }
    else { die "Unknown preset\n"; }
}
if (!defined $params) { die "Missing --preset or --params\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name.dnax-c";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_sequence  = "$temp_prefix-seq";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

my $cmd = "fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta'"
          . " | sequence-soft-mask-remove --mask '$temp_soft_mask'"
          . " | sequence-n-remove --n '$temp_n'"
          . " | sequence-iupac-remove --iupac '$temp_iupac'"
          . ($rna ? ' | sequence-u2t' : '')
          . " >'$temp_sequence'";
run($cmd);

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");
run("zstd -c -1 <'$temp_soft_mask' >'$out.soft-mask'");
run("zstd -c -1 <'$temp_n' >'$out.n'");
run("zstd -c -1 <'$temp_iupac' >'$out.iupac'");

if ($wrapper_only)
{
    move($temp_sequence, $out);
}
else
{
    run("dnaX '$temp_sequence' $params -O '$out' >/dev/null 2>&1");
    unlink $temp_sequence;
}

unlink $temp_fasta;
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
