#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

my ($in, $block_size);
GetOptions(
    'in=s'         => \$in,
    'block-size=s' => \$block_size,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (defined $block_size and $block_size !~ /^\d+m$/) { die "Unsupported format of --block-size argument\n"; }

my $block_size_arg = defined($block_size) ? " -b$block_size" : '';

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.brieflz-d-temp.fasta";

my $cmd = "blzpack -d$block_size_arg '$in' '$temp_fasta' >/dev/null 2>&1";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

if (!-e $temp_fasta) { exit(1); }

system("cat $temp_fasta");

unlink $temp_fasta;
