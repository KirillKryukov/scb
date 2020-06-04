#!/usr/bin/env perl

use strict;
use Cwd qw(abs_path cwd);
use File::Basename qw(basename);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

my $lfastqc_dir = '/data/kirill/tools/LFastqC';

binmode STDOUT;

my ($in, $rna, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'rna'          => \$rna,
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

my $temp_prefix = "$temp_dir/$name.lfastqc-d";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");

my $temp_fastq;
if ($wrapper_only)
{
    $temp_fastq = $in;
}
else
{
    make_path("$lfastqc_dir/temp");
    system("ln -f -s '" . abs_path("$in.LFastqC") . "' '$lfastqc_dir/temp/a.LFastqC'");
    system("ln -f -s '" . abs_path($in) . "' '$lfastqc_dir/temp/a.Seq'");
    system("ln -f -s '" . abs_path("$in.Qual") . "' '$lfastqc_dir/temp/a.Qual'");
    system("ln -f -s '" . abs_path("$in.sep.txt") . "' '$lfastqc_dir/temp/sep.txt'");
    my $start_dir = cwd();
    if (!chdir($lfastqc_dir)) { die "Can't change directory to \"$lfastqc_dir\"\n"; }
    my $cmd = "python2 decompress.py a.LFastqC >/dev/null 2>&1";
    run($cmd);
    if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }
    $temp_fastq = "$lfastqc_dir/a_fastq";
    if (!-e $temp_fastq) { die "Can't find decompressed fastq file after command:\n$cmd\n"; }
}

my $cmd = "fastq-to-sequence <'$temp_fastq'"
          . ($rna ? ' | sequence-t2u' : '')
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
run($cmd);

if (!$wrapper_only) { unlink $temp_fastq; }

unlink $temp_names;
unlink $temp_lengths;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
