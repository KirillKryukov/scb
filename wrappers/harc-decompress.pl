#!/usr/bin/env perl

use strict;
use Cwd qw(cwd abs_path);
use File::Basename qw(basename);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

my $harc_dir = '/data/kirill/build/HARC';

binmode STDOUT;

my ($in, $threads, $rna, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'threads=i'    => \$threads,
    'rna'          => \$rna,
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

my $start_dir = cwd();

my $new_temp_dir = "$temp_dir/$name-harc-d-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $temp_prefix = "$new_temp_dir/$name";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_seq;

if ($wrapper_only)
{
    $temp_seq = "$temp_prefix.seq";
    run("fastq-to-sequence <'$in' >'$temp_seq'");
}
else
{
    my $harc_link = "$temp_prefix.harc";
    run("ln -f -s '" . abs_path($in) . "' '$harc_link'");

    chdir $harc_dir;
    my $cmd = "./harc -d '$harc_link' -p -t $threads >/dev/null 2>&1";
    system($cmd);
    chdir $start_dir;

    $temp_seq = "$temp_prefix.dna.d";
    if (!-e $temp_seq) { die "Can't find \"$temp_seq\" after command:\n$cmd\n"; }

    unlink $harc_link;
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");
run("zstd -dc <'$in.n' >'$temp_n'");
run("zstd -dc <'$in.iupac' >'$temp_iupac'");

my $cmd = "cat '$temp_seq' '$in.tail'"
          . ' | sequence-merge-to-one-line'
          . ($rna ? ' | sequence-t2u' : '')
          . " | sequence-iupac-add --iupac '$temp_iupac'"
          . " | sequence-n-add --n '$temp_n'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
system($cmd);

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
