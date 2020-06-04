#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $threads, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'threads=i'    => \$threads,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $threads) { die "Number of threads is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.spring-c-temp-fasta";
my $temp_fastq = "$temp_dir/$name.spring-c-temp-fastq";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");
run("fasta-to-fastq --quality A <'$temp_fasta' >'$temp_fastq'");

if ($wrapper_only)
{
    move($temp_fastq, $out);
}
else
{
    run("spring -c -i '$temp_fastq' -o '$out' -w '$temp_dir' -t $threads -l --no-quality >/dev/null 2>&1");
    unlink $temp_fastq;
}

unlink $temp_fasta;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
