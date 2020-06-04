#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $rna, $protein, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'rna'          => \$rna,
    'protein'      => \$protein,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.blast-c-temp.fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

my $FA;
if ($rna) { open($FA, '|-', "fasta-u2t >'$temp_fasta'") or die "Can't create temporary file \"$temp_fasta\"\n"; }
else { open($FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n"; }
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

system("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

if ($wrapper_only)
{
    move($temp_fasta, $out);
}
else
{
    if ($protein)
    {
        run("makeblastdb -dbtype prot -title '' -in '$temp_fasta' -out '$out' >/dev/null 2>&1");
    }
    else
    {
        my $temp_mask = "$temp_dir/$name.blast-c-temp.mask";
        run("convert2blastmask -in '$temp_fasta' -masking_algorithm repeat -masking_options 'repeatmasker, default' -outfmt maskinfo_asn1_bin -out '$temp_mask'");
        run("makeblastdb -dbtype nucl -title '' -in '$temp_fasta' -mask_data '$temp_mask' -out '$out' >/dev/null 2>&1");
        unlink $temp_mask;
    }
    system(":>'$out'");
    unlink $temp_fasta;
}

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
