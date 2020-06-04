#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

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

open(my $P, '<', "$in.parameters") or die "Can't find parameters file\n"; ;
binmode $P;
my $parameters_string = <$P>;
close $P;
if ($parameters_string !~ /^(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)$/) { die "Can't parse parameters\n"; }
my ($hashSize, $context, $limit, $threshold, $chance) = ($1, $2, $3, $4, $5);

my $temp_prefix = "$temp_dir/$name.xm-d";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_fasta;

if ($wrapper_only)
{
    $temp_fasta = $in;
}
else
{
    $temp_fasta = "$temp_prefix-fa";
    run("jsa.xm.compress"
        . " --hashSize=$hashSize --context=$context --limit=$limit --threshold=$threshold --chance=$chance"
        . " --decode='$in' --output='$temp_fasta' >/dev/null 2>&1");
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");
run("zstd -dc <'$in.n' >'$temp_n'");
run("zstd -dc <'$in.iupac' >'$temp_iupac'");

my $cmd = "grep -v '>' '$temp_fasta'"
          . ' | sequence-merge-to-one-line'
          . " | sequence-iupac-add --iupac '$temp_iupac'"
          . " | sequence-n-add --n '$temp_n'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
run($cmd);

if (!$wrapper_only) { unlink $temp_fasta; }

unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_n;
unlink $temp_iupac;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
