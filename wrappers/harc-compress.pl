#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

my $read_length = 250;
my $harc_dir = '/data/kirill/build/HARC';

my ($out, $threads, $rna, $wrapper_only);
GetOptions(
    'out=s'         => \$out,
    'threads=i'     => \$threads,
    'rna'           => \$rna,
    'wrapper-only'  => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $threads) { die "Number of threads is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;
my $name_length = length($name);

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $start_dir = cwd();

my $new_temp_dir = "$temp_dir/$name-harc-c-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $temp_prefix = "$new_temp_dir/$name";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_seq       = "$temp_prefix-seq";
my $temp_fastq     = "$temp_prefix-fastq";

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
          . " >'$temp_seq'";
run($cmd);

my $seq_length = -s $temp_seq;

my ($head_length, $tail_length);
{
    use integer;
    $tail_length = $seq_length % $read_length;
    $head_length = $seq_length - $head_length;
}

run("head -c -$tail_length '$temp_seq' | fastq-from-sequence --seq-length $read_length --quality A >'$temp_fastq'");
run("tail -c $tail_length '$temp_seq' >'$out.tail'");

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");
run("zstd -c -1 <'$temp_soft_mask' >'$out.soft-mask'");
run("zstd -c -1 <'$temp_n' >'$out.n'");
run("zstd -c -1 <'$temp_iupac' >'$out.iupac'");

if ($wrapper_only)
{
    move($temp_fastq, $out);
}
else
{
    chdir $harc_dir;
    my $cmd = "./harc -c '$temp_fastq' -p -t $threads >/dev/null 2>&1";
    run($cmd);
    my $temp_harc = "$temp_fastq.harc";
    if (!-e $temp_harc) { die "Can't find \"$temp_harc\" after \"$cmd\"\n"; }
    chdir $start_dir;
    move($temp_harc, $out);
    unlink $temp_fastq;
}

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_n;
unlink $temp_iupac;
unlink $temp_seq;

remove_tree($new_temp_dir);

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
