#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(copy);
use Getopt::Long;

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

my $temp_fasta;
my $temp_name_ends = "$temp_dir/$name.2bit-d-temp-name-ends";

if ($wrapper_only)
{
    $temp_fasta = $in;
}
else
{
    $temp_fasta = "$temp_dir/$name.2bit-d-temp-fasta";
    run("twoBitToFa '$in' '$temp_fasta'");
}

my $len = `head -n 1 '$in.line-length'`;

system("zstd -dc <'$in.name-ends' >'$temp_name_ends'");

if ($wrapper_only)
{
    system("zstd -dc <'$in.name-ends-2' >'$temp_name_ends'");
}

my $cmd = "fasta-change-line-length --line-length $len <'$temp_fasta'"
             . " | fasta-add-name-ends --name-ends '$temp_name_ends'"
             . " | fasta-patch --diff '$in.iupac'";

if ($rna) { $cmd .= ' | fasta-t2u'; }

system($cmd);

if (!$wrapper_only) { unlink $temp_fasta; }
unlink $temp_name_ends;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
