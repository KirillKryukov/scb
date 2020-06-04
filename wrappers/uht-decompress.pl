#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(copy);
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

my $temp_uht = "$temp_dir/$name-d.uht";
copy($in, $temp_uht);
if (!-e $temp_uht) { die "Can't copy \"$in\" to \"$temp_uht\"\n"; }

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$temp_dir/$name.uht-d";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_fasta;

if ($wrapper_only)
{
    $temp_fasta = $temp_uht;
}
else
{
    my $decompress_cmd = "UHT-UHT-decompress '$temp_uht' >/dev/null";
    run($decompress_cmd);
    $temp_fasta = "$temp_dir/$name-d.fasta";
    if (!-e $temp_fasta) { die "Can't find \"$temp_fasta\" after $decompress_cmd\n"; }
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");

my $cmd = "fasta-to-sequence <'$temp_fasta'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
run($cmd);

if (!$wrapper_only) { unlink $temp_fasta; }

unlink $temp_uht;
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
