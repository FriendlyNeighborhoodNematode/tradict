#!/usr/bin/env perl

# srafish.pl - v0.11
# by Surge Biswas, Konstantin Kerner

######### UPDATE HISTORY ######################################################
# (20-04-15) v0.11 - added option to use an already existing query table.
#
#                    added subroutine to identify reference genotypes. if the
#                    keywords for one of the 19 MAGIC parents (e.g. "edi", case
#                    insensitive) is identified in column "library name", the
#                    respective reference matrix will be used. if no genotype
#                    can be identified, col reference will be used.
###############################################################################



use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Cwd;

my $cwd = getcwd;

my $query;
my $out 					= "";
my $query_table;
my $help;

GetOptions(
	"query=s"			=> \$query,
	"out=s"				=> \$out,
	"table=s"			=> \$query_table,
	"help"				=> \$help,
);

die <<USAGE

USAGE: srafish.pl -q 'query' -o /path/to/out(optional)

	-q		specify a query for Entrez search, e.g. '"Homo sapiens"[Organism] AND "strategy rna seq"[Properties]' to build a query table
	OR
	-t		use an already existing query table
	
	-o		path of your output directory
	-h		print this help message
	
USAGE

unless $query or $query_table;

if ($query and $query_table) {
	die "query AND table specified. please choose only one of these two options.";
}

chdir "$cwd/$out" if $out;

my $queries = 0;

if ($query_table) {
	
	open my $query_count, "<$query_table" or die $!;
	<$query_count>;
	$queries++ while <$query_count>;
	close $query_count;
	print STDERR "\nquery table found at $query_table! $queries queries identified\n";
}

else {
	$query_table = "query_results.csv";
	print STDERR "\nBuilding Query table . . .\n\n";	
	system("wget -O $query_table 'http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=$query'");
	
	
	open my $query_count, "<$query_table" or die $!;
	<$query_count>;
	$queries++ while <$query_count>;
	close $query_count;
	print STDERR "query table finished! $queries datasets identified\n";
}
	
open my $query_results, "<$query_table" or die $!;

<$query_results>; #skip header

my $i = 1;
my $experiment;
my $library_name;
my $layout;
my $genotype;

while (<$query_results>) {

	chomp;
	
	$_ =~ s/\".+?\"//g;

	my @line = split(/,/, $_);

	$experiment = $line[0];
	$library_name = $line[11];
	$layout = $line[15];
	

 	system("mkdir $cwd/$out/$experiment");

	if (-e "$cwd/$out/$experiment/quant.sf") {
		print STDERR "experiment $experiment already analysed. skipping . . .\n";
		$i++;
		next;
	}
	
	else {
		
		$genotype = &determine_genotype ($library_name);
		
		chdir "$cwd/$out/$experiment";
 		if ($layout =~ /paired/i) {
			print STDERR "\nfetching experiment: $experiment. Layout: $layout. Genotype: $genotype . . .\n";
			system("fastq-dump -I --split-files $experiment");
		}
	   
 		elsif ($layout =~ /single/i) {
			print STDERR "\nfetching experiment: $experiment. Layout: $layout. Genotype: $genotype . . .\n";
			system("fastq-dump $experiment");
		}
	   
 		else {
			print STDERR "\nfetching experiment: $experiment. Layout: NOT SPECIFIED! $layout treating as single. Genotype: $genotype . . .\n";
			system("fastq-dump $experiment");
		}
		
		#SAILFISH HERE
		chdir "$cwd/$out";
 		print STDERR "experiment $experiment finished! ", ($i / $queries) * 100, " % done.\n";
		$i++;
	}
}


###############################################################################

sub determine_genotype {
	
	my $name = shift @_;

	my %known_genotypes = (
		"bur"	=> "Bur_0",
		"can"	=> "Can_0",
		"ct"	=> "Ct_1",
		"edi"	=> "Edi_0",
		"hi"	=> "Hi_0",
		"kn"	=> "Kn_0",
		"ler"	=> "Ler_0",
		"mt"	=> "Mt_0",
		"no"	=> "No_0",
		"oy"	=> "Oy_0",
		"po"	=> "Po_0",
		"rsch"	=> "Rsch_4",
		"sf"	=> "Sf_2",
		"tsu"	=> "Tsu_0",
		"wil"	=> "Wil_2",
		"ws"	=> "Ws_0",
		"wu"	=> "Wu_0",
		"zu"	=> "Zu_0",
	);
	
	my $final_genotype = "Col_0";
	
	for my $known_genotype (keys(%known_genotypes)) {
		
#		print $known_genotype, "\n";
		if ($name =~ /$known_genotype[^a-z]/i){
			$final_genotype = $known_genotypes{$known_genotype};
			last;
		}
	}

	return $final_genotype;
}