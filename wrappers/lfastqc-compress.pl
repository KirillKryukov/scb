#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename dirname);
use File::Copy qw(move);
use File::Path qw(remove_tree);
use Getopt::Long;

my $lfastqc_dir = '/data/kirill/tools/LFastqC';

my ($out, $rna, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'rna'          => \$rna,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name.lfastqc-c";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_fastq     = "$lfastqc_dir/a.fastq";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

my $cmd = "fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta'"
          . ($rna ? ' | sequence-u2t' : '')
          #. ' | fastq-from-sequence --name-prefix "1." --seq-length 500 --quality A'
          . ' | fastq-from-sequence-2 --seq-length 500 --name-number-width 8 --quality A'
          . ($wrapper_only ? " >'$out'" : " >'$temp_fastq'");
run($cmd);

if ($wrapper_only)
{
    move($temp_fastq, $out);
}
else
{
    my $start_dir = cwd();
    if (!chdir($lfastqc_dir)) { die "Can't change directory to \"$lfastqc_dir\"\n"; }
    my $cmd = "python2 compress.py a.fastq >/dev/null 2>&1";
    run($cmd);
    if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }
    move("$lfastqc_dir/temp/a.LFastqC", "$out.LFastqC");
    move("$lfastqc_dir/temp/a.Seq", $out);
    move("$lfastqc_dir/temp/a.Qual", "$out.Qual");
    move("$lfastqc_dir/temp/sep.txt", "$out.sep.txt");
    remove_tree("$lfastqc_dir/a");
    remove_tree("$lfastqc_dir/temp");
    unlink $temp_fastq;
}

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
