#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use Getopt::Long;

my ($out_path, $level, $block_size);
GetOptions(
    'out=s'        => \$out_path,
    'level=s'      => \$level,
    'block-size=s' => \$block_size,
)
or die "Can't parse command line arguments\n";
if (!defined $out_path) { die "Output file is not specified\n"; }
if (defined $block_size and $block_size !~ /^\d+m$/) { die "Unsupported format of --block-size argument\n"; }
if (!defined $level) { die "Level is not specified\n"; }

my $level_arg = ($level eq 'optimal') ? '--optimal' : "-$level";
my $block_size_arg = defined($block_size) ? " -b$block_size" : '';

my $name = basename($out_path);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.brieflz-c-temp.fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

if (-e $out_path) { unlink $out_path; }
if (-e "$out_path.temp") { unlink "$out_path.temp"; }

my $cmd = "blzpack $level_arg$block_size_arg '$temp_fasta' '$out_path.temp' >/dev/null 2>&1";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

rename "$out_path.temp", $out_path;

unlink $temp_fasta;
