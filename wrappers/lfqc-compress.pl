#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my $lfqc_dir = '/data/kirill/build/lfqc/lfqc';

my ($out, $read_length, $wrapper_only);
GetOptions(
    'out=s'         => \$out,
    'read-length=i' => \$read_length,
    'wrapper-only'  => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $read_length) { die "Read length is not specified\n"; }
if ($read_length < 1 or $read_length > 4000) { die "Read length is out of range\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name";
my $temp_fasta   = "$temp_prefix-fa";
my $temp_names   = "$temp_prefix-names";
my $temp_lengths = "$temp_prefix-lengths";
my $temp_fastq   = "$temp_prefix.fastq";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

run("fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta'"
    . " | fastq-from-sequence --name-prefix 'seq' --seq-length $read_length --quality 'A' >'$temp_fastq'");

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");

if ($wrapper_only)
{
    move($temp_fastq, $out);
}
else
{
    my $start_dir = cwd();
    chdir($lfqc_dir);
    run("ruby lfqc.rb '$temp_fastq' >/dev/null 2>&1");
    chdir($start_dir);
    unlink $temp_fastq;
    move("$temp_fastq.lfqc", $out);
}

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
