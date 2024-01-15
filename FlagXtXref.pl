#!/usr/bin/env perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section FlagXtXref] [--logfile logfile.log] [--errfile errfile.err] [--eolrep #] [--reptag __hash__] [--debug] [file.sfm]\nA script that flags extended cross references for existence, ambiguity and duplication";

=pod
This script checks extended cross references.
An extended cross reference is one where the target has more than just the lx/lc field of the target.
It flags them as to the existence and status of the target:
Missing in the lc/lx/se fields
Ambiguous (Found but could be one of multiple homographs)
Missing in lc/lx/se but
found in another cf/lv – need to resolve.
not found
Found in a single – need to resolve/add to the other entry.


The ini file should have sections with syntax like this:
[FlagXtXref]
recmark=lx
hmmark=hm
semarks=se,sec,sed,sei,sep,sesec,sesed,sesep,seses
xrefmarks=lv,cf
lcmark=lc
REFflag=REF
dtmarks=dt,date
XtXrefEOL=__LS__

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
$USAGE =~ s/inifile\./$scriptname\./;
$USAGE =~ s/errfile\.err/$scriptname\-err.txt/;
$USAGE =~ s/logfile\.log/$scriptname\-log.txt/;

use Getopt::Long;
GetOptions (
	'inifile:s'   => \(my $inifilename = "$scriptname.ini"), # ini filename
	'section:s'   => \(my $inisection = "FlagXtXref"), # section of ini file to use
	'logfile:s'   => \(my $logfilename = "$scriptname-log.txt"), # log filename
	'errfile:s'   => \(my $errfilename = "$scriptname-err.txt"), # Error filename
	'eolrep:s' => \(my $eolrep = "#"), # character used to replace EOL
	'reptag:s' => \(my $reptag = "__hash__"), # tag to use in place of the EOL replacement character

	'help'    => \my $help,
# additional options go here.
# 'sampleoption:s' => \(my $sampleoption = "optiondefault"),
	'recmark:s' => \(my $recmark = "lx"), # record marker, default lx
	'debug'       => \my $debug,
	) or die $USAGE;
if ($help) {
	say STDERR $USAGE;
	exit;
	}


open(my $ERRFILE, '>', $errfilename)
	or die "Could not open Error file '$errfilename' $!";

open(my $LOGFILE, '>', $logfilename)
		or die "Could not open Log file '$logfilename' $!";

say STDERR "inisection:$inisection" if $debug;

use Config::Tiny;
my $config = Config::Tiny->read($inifilename, 'crlf');

my $hmmark;
my $srchSEmarks;
my $srchVAmarks;
my $lcmark;
my $xteol;
if ($config) {
	$recmark = $config->{"$inisection"}->{recmark};
	$hmmark = $config->{"$inisection"}->{hmmark};
	$lcmark = $config->{"$inisection"}->{lcmark};
	my $semarks = $config->{"$inisection"}->{semarks};
	 $xteol= $config->{"$inisection"}->{xteol};
	my $vamarks = $config->{"$inisection"}->{vamarks};
	$vamarks = "\N{INVERTED QUESTION MARK}\N{INVERTED QUESTION MARK}" if ! $vamarks; # should never match
	for ($recmark, $hmmark, $lcmark, $semarks,$vamarks) {
		# remove backslashes and spaces from the SFMs in the INI file
		say STDERR $_ if $debug;
		s/\\//g;
		s/ //g;
		}
	for ($semarks, $vamarks) {
		s/\,*$//; # no trailing commas
		s/\,/\|/g;  # use bars for or'ing
		}
	$srchSEmarks = qr/$semarks/;
	$srchVAmarks = qr/$vamarks/;
	}
else {
	die  "Couldn't find the INI file: $inifilename\n";
	}
say STDERR "record mark:$recmark" if $debug;
say STDERR "homograph mark:$hmmark" if $debug;
say STDERR "subentry marks Match: $srchSEmarks" if $debug;
say STDERR "variant marks Match: $srchVAmarks" if $debug;
say STDERR "citation mark:$lcmark" if $debug;
say STDERR "Extra EOL mark:$xteol" if $debug;

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
	elsif (/^\\$hmmark (.*?)#/) {
		my $hmval = $1;
		if ( (! $hmval) || # 0 or null
		  ($hmval !~ /^\d+$/) # test integer
		  ) {
			s/\\$hmmark/\\${hmmark}bad/;
			say $ERRFILE qq (Bad homograph number "$hmval" (not a positive integer), changing the SFM on line $.:$_);
			}
		 $line .= $_ ;
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
