#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

$ENV{'PATH'} = '/data/kirill/tools/deliminate:' . $ENV{'PATH'};

my ($out, $rna);
GetOptions(
    'out=s' => \$out,
    'rna'   => \$rna,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $start_dir = cwd();

my $new_temp_dir = "$temp_dir/$name-dlim-c-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $temp_fasta = "$new_temp_dir/$name.fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

my $FA;
if ($rna) { open($FA, '|-', "fasta-u2t >'$temp_fasta'") or die "Can't create temporary file \"$temp_fasta\"\n"; }
else { open($FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n"; }
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

if (!chdir($new_temp_dir)) { die "Can't change directory to \"$new_temp_dir\"\n"; }

my $cmd = "delim a '$name.fasta' >/dev/null";
my $error = system($cmd);
if ($error) { die "Command failed: $cmd\n"; }

if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }

my $temp_dlim = "$temp_fasta.dlim";
if (!-e $temp_dlim) { exit(1); }

move($temp_dlim, $out);

unlink $temp_fasta;
remove_tree($new_temp_dir);
