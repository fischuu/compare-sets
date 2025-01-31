#!/usr/bin/perl
use strict;
use Bio::SeqIO;
########################################################################################################################################
# This script computes the overlap between two sets of sequences. User can either provide two sets that will be compared 
# (using the -1 and -2 flags) or a set of sequences ("query", -1) and a pool of sequences from which sequences that have significant
# hits to the query set will be chosen as the second set. Similarity is measured based on the number of aligned bps between the two sets
# where the alignment is performed using nucmer and uses $pidentity_ovlp as the % identity threshold (96% by default). Each base is
# counted only once, even if it aligns to more than one sequence from the other set.
# To run this script you'll need to have the MUMmer package installed on your system (http://mummer.sourceforge.net/) and also bioperl.
#
# Written by Itai Sharon, itai.sharon@gmail.com (4/21/13).
# v1.01 (5/6/18): prepared for publication.
########################################################################################################################################
($#ARGV >= 5) || die "\nUsage: $0 -1 <set1-scafs> -2 <set2-scafs> -o <out-prefix> [--silent] [-p <% identity threshold>]\n\n";

# Change the path according to the path in your system
my $nucmer = 'nucmer';
my $show_coords = 'show-coords';

my ($set1_scafs_file, $set2_scafs_file, $out_prefix) = (undef, undef, undef);
my $verbose = 1;
my $pidentity_ovlp = 96;

while($#ARGV > -1) {
	my $flag = shift(@ARGV);
	if($flag eq '-1') {
		$set1_scafs_file = shift(@ARGV);
	}
	elsif($flag eq '-2') {
		$set2_scafs_file = shift(@ARGV);
	}
	elsif($flag eq '-o') {
		$out_prefix = shift(@ARGV);
	}
	elsif($flag eq '-p') {
		$pidentity_ovlp = shift(@ARGV);
	}
	elsif($flag eq '--silent') {
		$verbose = 0;
	}
	else {
		die "\nUnknown option: $flag\n\n";
	}
}
defined($set1_scafs_file) || die "\nFirst set of scaffolds was not specified (-1)\n\n";
defined($set2_scafs_file) || die "\nsecond set of scaffolds was not specified (-2)\n\n";
defined($out_prefix) || die "\nOutput prefix (-o) was not specified\n\n";

my ($delta_file, $coords_file, $report_file, $log_file) = ("$out_prefix.delta", "$out_prefix.coords", "$out_prefix.report.txt", "$out_prefix.log");

my %set1_scafs = ();
my %set2_scafs = ();

my $in = new Bio::SeqIO(-file => $set1_scafs_file);
while(my $seq = $in->next_seq) {
#die $seq->display_id . "\t" . $seq->length . "\n\n";
	my @temp = split(//, ('0' x ($seq->length+1)));
	$set1_scafs{$seq->display_id} = \@temp;
}


my $in = new Bio::SeqIO(-file => $set2_scafs_file);
while(my $seq = $in->next_seq) {
	my @temp = split(//, ('0' x ($seq->length+1)));
	$set2_scafs{$seq->display_id} = \@temp;
}

#system("$nucmer --maxmatch -c 100 -b 100 -p $out_prefix $set1_scafs_file $set2_scafs_file 2>> $log_file");
system("$nucmer -c 100 -b 100 -p $out_prefix $set1_scafs_file $set2_scafs_file 2>> $log_file");
system("$show_coords -r -c -l $delta_file > $coords_file 2>> $log_file");

open(IN, $coords_file) || die "\nCannot read $coords_file\n\n";

#    [S1]     [E1]  |     [S2]     [E2]  |  [LEN 1]  [LEN 2]  |  [% IDY]  |  [LEN R]  [LEN Q]  |  [COV R]  [COV Q]  | [TAGS]
$_ = <IN>;
# ===============================================================================================================================
$_ = <IN>;
while(<IN>) {
	#     331     2962  |     4137     1506  |     2632     2632  |    99.54  |    72864     4409  |     3.61    59.70  | scaffold_1014	scaffold_3650
	chomp;
	my @fs = split(/\s+/);
	next if($fs[10] < $pidentity_ovlp);
	foreach my $i ($fs[1] .. $fs[2]) {
		$set1_scafs{$fs[18]}->[$i] = 1;
	}
	($fs[4], $fs[5]) = ($fs[5], $fs[4]) if($fs[4] > $fs[5]);
	foreach my $i ($fs[4] .. $fs[5]) {
		$set2_scafs{$fs[19]}->[$i] = 1;
	}
}

open(OUT, ">$report_file") || die "\nCannot write to $report_file\n\n";
print OUT "### $set1_scafs_file ###\n\n";
my ($total, $total_covered) = (0, 0);
foreach my $scaf (keys %set1_scafs) {
	my $covered = 0;
	foreach my $i (0 .. $#{$set1_scafs{$scaf}}) {
		$covered += $set1_scafs{$scaf}->[$i];
	}
	$total_covered += $covered;
	$total += scalar(@{$set1_scafs{$scaf}})-1;
	print OUT "$scaf\t", scalar(@{$set1_scafs{$scaf}}), "\t$covered\t", (int(1000*$covered/(scalar(@{$set1_scafs{$scaf}})-1))/10), "\n"; 
}

print STDERR "$total_covered/$total (", (int(1000*$total_covered/$total)/10), "\%) are covered in $set1_scafs_file\n";
print OUT "\n$total_covered/$total (", (int(1000*$total_covered/$total)/10), "\%) are covered in $set1_scafs_file\n";

print OUT "\n### $set2_scafs_file ###\n\n";
($total, $total_covered) = (0, 0);
foreach my $scaf (keys %set2_scafs) {
	my $covered = 0;
	foreach my $i (0 .. $#{$set2_scafs{$scaf}}) {
		$covered += $set2_scafs{$scaf}->[$i];
	}
	$total_covered += $covered;
	$total += scalar(@{$set2_scafs{$scaf}})-1;
	print OUT "$scaf\t", scalar(@{$set2_scafs{$scaf}}), "\t$covered\t", (int(1000*$covered/(scalar(@{$set2_scafs{$scaf}})-1))/10), "\n"; 
}
print STDERR "$total_covered/$total (", (int(1000*$total_covered/$total)/10), "\%) are covered in $set2_scafs_file\n";
print OUT "\n$total_covered/$total (", (int(1000*$total_covered/$total)/10), "\%) are covered in $set2_scafs_file\n";
close(OUT);
