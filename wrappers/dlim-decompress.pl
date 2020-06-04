#!/usr/bin/env perl

use strict;
use Cwd qw(cwd abs_path);
use File::Copy qw(copy);
use File::Basename qw(basename);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

my ($in, $rna);
GetOptions(
    'in=s' => \$in,
    'rna'  => \$rna,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }

$ENV{'PATH'} = '/data/kirill/tools/deliminate:' . $ENV{'PATH'};

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $new_temp_dir = "$temp_dir/$name-dlim-d-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $start_dir = cwd();
my $dlim_link = "$new_temp_dir/$name.dlim";
system("ln -f -s '" . abs_path($in) . "' '$dlim_link'");

my $temp_fasta = "$new_temp_dir/$name.fasta";

if (!chdir($new_temp_dir)) { die "Can't change directory to \"$new_temp_dir\"\n"; }

my $cmd = "delim e '$name.dlim' '$name.fasta' >/dev/null";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }

if (!-e $temp_fasta) { die "Failed to produce temporary FASTA file \"$temp_fasta\""; }

$cmd = $rna ? "fasta-t2u <'$temp_fasta'" : "cat '$temp_fasta'";
system($cmd);

unlink $temp_fasta;
unlink $dlim_link;
remove_tree($new_temp_dir);
