use strict;
use Test::More tests => 3;

BEGIN { use_ok "WebService::FreeDB"; }

# testing retrieving of cdlist
{
    my $cddb = WebService::FreeDB->new();
    my %discs = $cddb->getdiscs("metallica", ["artist","title"] );
    ok( (keys %discs) > 0, "Fetched some discs");
}

#testing retriving of a cd
{
    my $cddb = WebService::FreeDB->new();
    my $url = 'http://www.freedb.org/freedb_search_fmt.php?cat=rock&id=b50ec40c';
    my %discinfo = $cddb->getdiscinfo($url);
    ok( $discinfo{totaltime} eq '63:02', "Disc has right length");
}
