#!/usr/bin/perl -w

use WebService::FreeDB;
use Data::Dumper;
$usage='cdget.pl [options] <keyword> <field>...
  <keyword>:   keyword for search
  <field>:     one or more of:artist|title|track|rest (space sep.)
  known options:
  --debug=[0,1,2,3]:   Debug information (default=0)
  -outformat=[std|Dumper]:   Output format of selected discs
  TBC...
';
my $debuglevel = 0;
my $outformat = "std";

while (defined($ARGV[0]) && $ARGV[0] =~ /^-.+$/) {
  my $opt = shift;
  if ($opt =~ /-debug=(\d)/) {
	$debuglevel = $1;
  } elsif ($opt =~ /outformat=(std|dumper)/i) {
	$outformat = $1;
  } else {
	print "unknown option:$opt\n";
	print $usage;
	exit 0;
  }
}
if (!defined($ARGV[1])) {
  print $usage;
  exit 0;
  }
$keyword = shift;
@fields = @ARGV;

# 1st lets create a object ...
#$debuglevel = 0; #maybe 0..3
#$keyword = "Fury in the Slaughterhouse"; #setting the keywords ...
#@fields = (artist,rest) # may combination from artist,titel,rest,track

$cddb = WebService::FreeDB->new(DEBUG=>$debuglevel);

#2nd gets a list of discs, which are matching to $keyword in @fields
%discs = $cddb->getdiscs($keyword,\@fields);
#3rd asks user to select one or more of the found discs
@selecteddiscs = $cddb->ask4discurls(\%discs);
for my $url (@selecteddiscs) {
  #4th get the discinfo
  my %discinfo = $cddb->getdiscinfo($url);
  #5th prints the discinfo out
  if ($outformat =~ /Dumper/i) {$cddb->outdumper(\%discinfo)}
  elsif ($outformat =~/std/i) {$cddb->outstd(\%discinfo)}
  else {die "unknown outtype"}
}
#6th: We are happy !
#

