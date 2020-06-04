#!/usr/bin/env perl

use strict;
use Cwd qw(abs_path);
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

if ($wrapper_only)
{
    system("cat $in");
}
else
{
    my $ac_link = "$temp_dir/$name.fa.co";
    system("ln -f -s '" . abs_path($in) . "' '$ac_link'");

    my $cmd = "AD '$ac_link' >/dev/null 2>&1";
    my $error = system($cmd);
    if ($error) { die "Command failed: $cmd\n"; }

    my $temp_fasta = "$temp_dir/$name.fa.de";
    if (!-e $temp_fasta) { die "Failed to produce temporary FASTA file \"$temp_fasta\""; }
    system("cat $temp_fasta");
    unlink $temp_fasta;
    unlink $ac_link;
}
