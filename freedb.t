use lib '../blib/lib','../blib/arch';

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use WebService::FreeDB;

$loaded = 1;
print "ok 1\n";

#testing retrieving of cdlist
$cddb1 = WebService::FreeDB->new();
%discs = $cddb1->getdiscs("metallica",("artist","titel"));
if (length(keys(%discs)) > 0) { print "ok 2\n"; } else { print "not ok 2\n"; }

#testing retriving of a cd
$cddb2 = WebService::FreeDB->new();
$url = 'http://www.freedb.org/freedb_search_fmt.php?cat=rock&id=b50ec40c';
my %discinfo = $cddb2->getdiscinfo($url);
if ($discinfo{totaltime} eq '63:02' ) { print "ok 3\n"; } else { print "not ok 3\n"; }
