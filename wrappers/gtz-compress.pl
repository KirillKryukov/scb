#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $level, $threads, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'level=i'      => \$level,
    'threads=i'    => \$threads,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $level) { die "Level is not specified\n"; }
if (!defined $threads) { die "Number of threads is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_prefix = "$temp_dir/$name.gtz-c";
my $temp_fasta = "$temp_prefix-fa";
my $temp_fastq = "$temp_prefix-fq";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");
run("fasta-to-fastq --quality 'A' <'$temp_fasta' >'$temp_fastq'");

if ($wrapper_only)
{
    move($temp_fastq, $out);
}
else
{
    run("gtz '$temp_fastq' -p $threads -l $level -o '$out.gtz' >/dev/null 2>&1");
    rename "$out.gtz", $out;
    unlink $temp_fastq;
}

unlink $temp_fasta;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
