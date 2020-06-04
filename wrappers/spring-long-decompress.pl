#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

binmode STDOUT;

my ($in, $threads, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'threads=i'    => \$threads,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }
if (!defined $threads) { die "Number of threads is not specified\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $len = `head -n 1 '$in.line-length'`;

if ($wrapper_only)
{
    run("fastq-to-fasta <'$in' | fasta-change-line-length --line-length $len");
}
else
{
    my $temp_fastq = "$temp_dir/$name.spring-d-temp-fastq";
    run("spring -d -i '$in' -o '$temp_fastq' -w '$temp_dir' -t $threads >/dev/null 2>&1");
    run("tr '\@' '>' <'$temp_fastq' | fasta-change-line-length --line-length $len");
    unlink $temp_fastq;
}

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
