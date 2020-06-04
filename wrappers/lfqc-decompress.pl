#!/usr/bin/env perl

use strict;
use Cwd qw(cwd abs_path);
use File::Basename qw(basename);
use Getopt::Long;

my $lfqc_dir = '/data/kirill/build/lfqc/lfqc';

binmode STDOUT;

my ($in, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$temp_dir/$name";
my $temp_names   = "$temp_prefix-names";
my $temp_lengths = "$temp_prefix-lengths";
my $temp_fastq;

if ($wrapper_only)
{
    $temp_fastq = $in;
}
else
{
    $temp_fastq = "$temp_dir/$name.fastq";
    my $temp_lfqc_link = "$temp_fastq.lfqc";
    run("ln -f -s '" . abs_path($in) . "' '$temp_lfqc_link'");
    my $start_dir = cwd();
    chdir($lfqc_dir);
    run("ruby lfqcd.rb '$temp_lfqc_link' >/dev/null 2>&1");
    chdir($start_dir);
    unlink $temp_lfqc_link;
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");

run("fastq-to-sequence <'$temp_fastq'"
    . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len");

if (!$wrapper_only) { unlink $temp_fastq; }

unlink $temp_names;
unlink $temp_lengths;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
