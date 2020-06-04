#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

my ($out_path, $hashsize, $treesize, $treetype);
GetOptions(
    'out=s'      => \$out_path,
    'hashsize=i' => \$hashsize,
    'treesize=i' => \$treesize,
    'treetype=s' => \$treetype,
)
or die "Can't parse command line arguments\n";
if (!defined $out_path) { die "Output file is not specified\n"; }
if (!defined $hashsize) { die "hashsize is not specified\n"; }
if (!defined $treesize) { die "treesize is not specified\n"; }
if (!defined $treetype) { die "treetype is not specified\n"; }

my $name = basename($out_path);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $start_dir = cwd();

my $new_temp_dir = "$temp_dir/$name-nakamichi-c-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $temp_fasta = "$new_temp_dir/$name.fa";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

if (!chdir($new_temp_dir)) { die "Can't change directory to \"$new_temp_dir\"\n"; }

my $cmd = "nakamichi '$name.fa' '$name.fa.Nakamichi' $hashsize $treesize $treetype >/dev/null 2>&1";
run($cmd);

if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }

my $temp_nakamichi = "$new_temp_dir/$name.fa.Nakamichi";
if (!-e $temp_nakamichi) { die "Can't find \"$temp_nakamichi\" after command:\n$cmd\n"; }

move($temp_nakamichi, $out_path);

unlink $temp_fasta;
remove_tree($new_temp_dir);

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
