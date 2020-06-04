#!/usr/bin/env perl

use strict;
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

my $cmd;
if ($wrapper_only)
{
    $cmd = "cat '$in'";
}
else
{
    $cmd = "blastdbcmd -db '$in' -entry all";
    if (-e "$in.naa" or -e "$in.00.naa") { $cmd .= ' -mask_sequence_with 40'; }

    my $line_length_file = "$in.line-length";
    if (-e $line_length_file)
    { 
        chomp(my $len = `head -n 1 '$line_length_file'`);
        if ($len =~ /^\d+$/) { $cmd .= ' -line_length ' . $len; }
    }
}

if ($rna) { $cmd .= ' | fasta-t2u'; }

system($cmd);
