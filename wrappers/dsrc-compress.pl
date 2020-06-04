#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $level, $buffer_size, $threads, $rna, $wrapper_only);
GetOptions(
    'out=s'         => \$out,
    'level=i'       => \$level,
    'buffer-size=i' => \$buffer_size,
    'threads=i'     => \$threads,
    'rna'           => \$rna,
    'wrapper-only'  => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $level) { die "Level is not specified\n"; }
if (!defined $buffer_size) { die "Buffer size is not specified\n"; }
if (!defined $threads) { die "Number of threads is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name.dsrc-c";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_iupac     = "$temp_prefix-iupac";

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
          . " | sequence-iupac-remove --iupac '$temp_iupac'"
          . ($rna ? ' | sequence-u2t' : '')
          . ' | fastq-from-sequence --seq-length 500 --quality A'
          . ($wrapper_only ? " >'$out'" : " | dsrc c -d$level -q0 -b$buffer_size -t$threads -s '$out' 2>/dev/null");
run($cmd);

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");
run("zstd -c -1 <'$temp_soft_mask' >'$out.soft-mask'");
run("zstd -c -1 <'$temp_iupac' >'$out.iupac'");

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_iupac;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
