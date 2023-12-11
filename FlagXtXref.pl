#!/usr/bin/env perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section FlagXtXref] [--eolrep #] [--reptag __hash__] [--debug] [file.sfm]\nA script that flags cross references for existence, ambiguity and duplication";

=pod
This script is a stub that provides the code for opl'ing and de_opl'ing an input file
It also includes code to:
	- use an ini file (commented out)
	- process command line options including debugging

The ini file should have sections with syntax like this:
[FlagXtXref]
recmark=lx
hmmark=hm
semarks=se,sec,sed,sei,sep,sesec,sesed,sesep,seses
xrefmarks=lv,cf
lcmark=lc
REFflag=REF
dtmarks=dt,date
preprocess=s{^\\lf .*?__LS__}{};

=cut
use 5.020;
use utf8;
use open qw/:std :utf8/;

use strict;
use warnings;
use English;
use Data::Dumper qw(Dumper);


use File::Basename;
my $scriptname = fileparse($0, qr/\.[^.]*/); # script name without the .pl

use Getopt::Long;
GetOptions (
	'inifile:s'   => \(my $inifilename = "$scriptname.ini"), # ini filename
	'section:s'   => \(my $inisection = "section"), # section of ini file to use
# additional options go here.
# 'sampleoption:s' => \(my $sampleoption = "optiondefault"),
	'recmark:s' => \(my $recmark = "lx"), # record marker, default lx
	'eolrep:s' => \(my $eolrep = "#"), # character used to replace EOL
	'reptag:s' => \(my $reptag = "__hash__"), # tag to use in place of the EOL replacement character
	# e.g., an alternative is --eolrep % --reptag __percent__

	# Be aware # is the bash comment character, so quote it if you want to specify it.
	#	Better yet, just don't specify it -- it's the default.
	'debug'       => \my $debug,
	) or die $USAGE;

# check your options and assign their information to variables here
$recmark =~ s/[\\ ]//g; # no backslashes or spaces in record marker

# if you do not need a config file ucomment the following and modify it for the initialization you need.
# if you have set the $inifilename & $inisection in the options, you only need to set the parameter variables according to the parameter names
# =pod
use Config::Tiny;
my $config = Config::Tiny->read($inifilename, 'crlf');
die "Quitting: couldn't find the INI file $inifilename\n$USAGE\n" if !$config;
my $param1 = $config->{"$inisection"}->{Param1};
say STDERR "Param1:$param1" if $debug;
my $param2 = $config->{"$inisection"}->{Param2};
say STDERR "Param2:$param2" if $debug;
# =cut

# generate array of the input file with one SFM record per line (opl)
my @opledfile_in;
my $line = ""; # accumulated SFM record
my $crlf;
while (<>) {
	$crlf = $MATCH if  s/\R//g;
	s/$eolrep/$reptag/g;
	$_ .= "$eolrep";
	if (/^\\$recmark /) {
		$line =~ s/$eolrep$/$crlf/;
		push @opledfile_in, $line;
		$line = $_;
		}
	else { $line .= $_ }
	}
push @opledfile_in, $line;

say STDERR "opledfile_in:", Dumper(@opledfile_in) if $debug;
for my $oplline (@opledfile_in) {
# Insert code here to perform on each opl'ed line.
# Note that a next command will prevent the line from printing

say STDERR "oplline:", Dumper($oplline) if $debug;
#de_opl this line
	for ($oplline) {
		$crlf=$MATCH if /\R/;
		s/$eolrep/$crlf/g;
		s/$reptag/$eolrep/g;
		print;
		}
	}
