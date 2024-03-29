#!/usr/bin/env perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section FlagXtXref] [--logfile logfile.log] [--errfile errfile.err] [--eolrep #] [--reptag __hash__] [--debug] [file.sfm]\nA script that flags extended cross references for existence, ambiguity and duplication";

=pod
This script checks extended cross references.
An extended cross reference is one where the target has more than just the lx/lc field of the target.
It flags them as to the existence and status of the target:
1) Missing in the lc/lx/se fields
2) Ambiguous (Found but could be one of multiple homographs)
3) Missing in lc/lx/se but found in another cf/lv – need to resolve.
4) not found
5) Found in a single – need to resolve/add to the other entry.

## Data Structures Used
- @opledfile_in - an array with the each SFM record as a separate item
	- The first item may be Toolbox header
- @recordindex - an array of the line numbers of the SFM records
 - %xreftarget - A hash of the database keyed on the text of the lx/lc or /se* field.
	- The value of the hash is a comma separated list of matching items
		- homographno<tab>recordno<tab>linenoinrecord
		- the linenoinrecord is 0 for \lx targets; the line offset for \lc and \se*
For example (taken from https://github.com/WesPeacock/SampleSFM/blob/master/earBayullBayoleMay.db):
If the 14th SFM record starts on line# 300 and is:
	\lx olemay
	\hm 2
	\et Old English: mal
	\ps n
	\ge mole
	\de a small dark skin blemish
Then:
	$opledfile_in[13] = "\lx olemay#\hm 2#\et Old English: mal#\ps n#\ge mole#\de a small dark skin blemish##"
	$recordindex[13] = 300
	$xreftarget{"olemay"} is a string that lists the homographs and indexes of "olemay"; it contains "2<tab>13<tab>0"
	E.g. if you add the following to the end of the script, and run the script on
	my $x = $xreftarget{"olemay"};
		say STDERR qq{xreftarget{"olemay"}:$x};
	 This will be the output on STDERR:
		xreftarget{"olemay"}:1  12  0,2 13  0,3 14  0,4 15  0
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
my $srchXREFmarks;
my $lcmark;
my $xteol;
if ($config) {
	$recmark = $config->{"$inisection"}->{recmark};
	$hmmark = $config->{"$inisection"}->{hmmark};
	my $semarks = $config->{"$inisection"}->{semarks};
	my $xrefmarks = $config->{"$inisection"}->{xrefmarks};
	$lcmark = $config->{"$inisection"}->{lcmark};
	 $xteol= $config->{"$inisection"}->{xteol};
	for ($recmark, $hmmark, $lcmark, $semarks, $xrefmarks) {
		# remove backslashes and spaces from the SFMs in the INI file
		say STDERR $_ if $debug;
		s/\\//g;
		s/ //g;
		}
	for ($semarks, $xrefmarks) {
		s/\,*$//; # no trailing commas
		s/\,/\|/g;  # use bars for or'ing
		}
	$srchSEmarks = qr/$semarks/;
	$srchXREFmarks = qr/$xrefmarks/;
	}
else {
	die  "Couldn't find the INI file: $inifilename\n";
	}
say STDERR "record mark:$recmark" if $debug;
say STDERR "homograph mark:$hmmark" if $debug;
say STDERR "subentry marks Match: $srchSEmarks" if $debug;
say STDERR "citation mark:$lcmark" if $debug;
say STDERR "Extra EOL mark:$xteol" if $debug;

# generate array of the input file with one SFM record per line (opl)
my @opledfile_in;
my @recordindex;	# line number of the start of the record
push @recordindex, 1;

my $line = ""; # accumulated SFM record
my $crlf;
while (<>) {
	$crlf = $MATCH if  s/\R//g;
	s/$eolrep/$reptag/g;
	$_ .= "$eolrep";
	if (/^\\$recmark /) {
		$line =~ s/$eolrep$/$crlf/;
		push @opledfile_in, $line;
		push @recordindex, $NR;
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

my $sizeopl = scalar @opledfile_in;
say STDERR "size opl:", $sizeopl if $debug;

#print STDERR Dumper(@opledfile_in) if $debug;
say STDERR "size index:", scalar @recordindex  if $debug;
#print STDERR Dumper(@recordindex) if $debug;

my %xreftarget;	# contains the index(es) of a lexical item in the opl array
for (my $oplindex=0; $oplindex < $sizeopl; $oplindex++) {
	my $oplline = $opledfile_in[$oplindex];
	next if ! ($oplline =~  m/\\$recmark ([^#]*)/); # e.g. Shoebox header line
	my $lxkey =  $1;
	my $linecount = 0;
	if ($oplline =~  m/\\$lcmark ([^#]*)/) {
		$lxkey =  $1;
		my $beforefields = $PREMATCH;
		$linecount = () = $beforefields =~ /$eolrep/g; # HT:https://stackoverflow.com/a/1849356/
		}
	my $hmno ="";
	$oplline =~  m/^([^#]+#){1,4}/; # first (up to) 4 fields
	my $hmcheck = $MATCH;
	if ($hmcheck =~ m/\\$hmmark ([^#]*)/) {
		$hmno =$1;
		}
	say STDERR "lxkey(maybe citation):", $lxkey if $debug;
	if (exists $xreftarget{$lxkey}) {
		$xreftarget{$lxkey} = $xreftarget{$lxkey} . "," . "$hmno\t$oplindex\t$linecount";
		}
	else {
		$xreftarget{$lxkey} = "$hmno\t$oplindex\t$linecount";
		}
	while ($oplline =~ /\\$srchSEmarks ([^$eolrep]+)$eolrep/g) {
		my $sekey=$1;
		my $beforefields=$PREMATCH;
		my $afterfields=$POSTMATCH;
		my $hmno ="";
		$afterfields =~  m/^([^#]+#){1,4}/; # (up to) 4 fields following the \se marker
		my $hmcheck = $MATCH;
		if ($hmcheck =~ m/\\$hmmark ([^#]*)/) {
			$hmno =$1;
			}
#		say STDERR "sekey=$sekey\nbeforefields=$beforefields\nafterfields=$afterfields\nhmcheck=$hmcheck" if $debug;
		my $linecount = () = $beforefields =~ /$eolrep/g; # HT:https://stackoverflow.com/a/1849356/
		if (exists $xreftarget{$sekey}) {
			$xreftarget{$sekey} = $xreftarget{$sekey} . "," . "$hmno\t$oplindex\t$linecount";
			}
		else {
			$xreftarget{$sekey} = "$hmno\t$oplindex\t$linecount";
			}
		}
	}
print STDERR "xreftarget:\n" . Dumper(%xreftarget) if $debug;

foreach my $targetkey ( sort keys %xreftarget) {
	my @hmvals = split(/,/, $xreftarget{$targetkey});
	my @hmnos;
	foreach (@hmvals) {
		(my $hmno) = split/\t/;
		push @hmnos, $hmno;
		}
	# check for duplicate hmnos HT:https://stackoverflow.com/a/3012127
	my %seen; #  a count of the number of times each hmno is seen
	foreach my $hmno (@hmnos) {
		$seen{$hmno}++;
		}
	foreach my $seenkey (keys %seen) { # Flag duplicates
		if ($seen{$seenkey} > 1) {
			 if (! $seenkey) { # not null
				say $ERRFILE qq[Entries for "$targetkey" are duplicated with no homograph#];
				 }
			else {
				 say $ERRFILE qq[Entries for "$targetkey" have duplicate homograph #$seenkey];
				}
			foreach my $hmdupe (grep (/^$seenkey\t/, @hmvals)) {
				(undef, my $recno, my $lineno) =  split(/\t/, $hmdupe);
				say $ERRFILE "At line " , ($recordindex[$recno]+ $lineno);
				}
			say $ERRFILE "";
			}
		}
	if (grep (/^\t/, @hmvals) && grep (/^[^\t]/, @hmvals)) { # flag duplicate entries with no hm#
		print $ERRFILE qq[Entries for "$targetkey" have unmarked homograph(s) at lines: ];
		my $linenos = "";
		foreach my $nohm (sort grep (/^\t/, @hmvals)) {
			(undef, my $recno, my $lineno) =  split(/\t/, $nohm);
			$linenos = $linenos . ($recordindex[$recno]+ $lineno) . ", ";
			}
		$linenos =~ s/, $//;
		say $ERRFILE $linenos;
		$linenos = "";
		print $ERRFILE qq[and homograph number(s) at line(s) (line#:hm#): ];
		foreach my $hmrec (sort grep (/^[^\t]/, @hmvals)) {
			(my $hmno, my $recno, my $lineno) =  split(/\t/, $hmrec);
			$linenos = $linenos . "\(" . ($recordindex[$recno]+ $lineno) . ":$hmno\), ";
			}
		$linenos =~ s/, $//;
		say $ERRFILE $linenos;
		say $ERRFILE "";
		}
	}

for (my $oplindex=0; $oplindex < $sizeopl; $oplindex++) {
	my $oplline = $opledfile_in[$oplindex];
	while ($oplline =~ /(\\$srchXREFmarks) ([^$eolrep]+)$eolrep/g) {
		my $xrefmarker = $1;
		my $xreftxt=$2;
		my $beforefields=$PREMATCH;
		my $linecount = () = $beforefields =~ /$eolrep/g;
		$linecount =$linecount + $recordindex[$oplindex]+ $linecount;
		$xreftxt =~ s/\d+$//;
		my $hmno = $MATCH;
		# detect no match on xreftxt
		if (! exists $xreftarget{$xreftxt}) {
			say $ERRFILE qq[No target found for "$xrefmarker $xreftxt" on line# $linecount];
			next;
			}
		# detect match on text but not homograph
		# match with homograph -> to logfile
		# exclude text from $xteol to $eolrep
		}
	}

for (my $oplindex=0; $oplindex < $sizeopl; $oplindex++) {
	my $oplline = $opledfile_in[$oplindex];
	say STDERR "oplline:", Dumper($oplline) if $debug;
	#de_opl this line
	for ($oplline) {
		$crlf=$MATCH if /\R/;
		s/$eolrep/$crlf/g;
		s/$reptag/$eolrep/g;
		print;
		}
	}

=pod
		# && ($xreftarget{$lxkey} =~ m/\t$hmno(,|$)/)) {
		print $ERRFILE qq/record "$lxkey" on line $recordindex[$oplindex] is also on line(s) /;
		my @rindxs;
		for my $i (split ( /,/, $xreftarget{$lxkey})) {
			$i =~  m/[^\t]*/; # remove homograph number
			push @rindxs, $recordindex[$MATCH];
			}
		say $ERRFILE join (", ", @rindxs);

=cut
