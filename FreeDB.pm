package WebService::FreeDB;
use Data::Dumper;
use LWP::Simple;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw//;
@EXPORT_OK = qw/getdiscs getdiscinfo ask4discurls outdumper outstd/;
$VERSION = '0.55';

sub new {
  my $class = shift;
  my $self = {};
  $self->{ARG} = {@_};
  if(!defined($self->{ARG}->{HOST})) {$self->{ARG}->{HOST}='http://www.freedb.org'}  #Maybe there are some other freedb-web-interfaces ?!
  if(!defined($self->{ARG}->{PATH})) {$self->{ARG}->{PATH}='/freedb_search.php'}
  if(!defined($self->{ARG}->{DEFAULTVALUES})) {$self->{ARG}->{DEFAULTVALUES}='allfields=NO&grouping=none'}
  bless($self, $class);
  $self ? return $self : return undef;
}

#####
# Give this method a keyword,a array of fields and a array of categories (or nothing)
# and it will search on the server for matching cds
# returns a hash urls->(artist,album)
#####
sub getdiscs {
  my $self = shift;
  my @keywords = split(/ /,shift);
  my @fields = @{$_[0]};
  if(defined $_[1]) {@cats = @{$_[1]};}
  my %discs;
  my $url = $self->{ARG}->{HOST}.$self->{ARG}->{PATH}."?".$self->{ARG}->{DEFAULTVALUES};


  $url .="&words=".shift(@keywords);
  for my $word (@keywords) {
	$url .= "+".$word;
  }
  

  for my $field (@fields) {
    if(!($field =~ /^(artist|title|track|rest)$/)) {
      print STDERR "*unknown field-type: $field;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	  next;
	}
	$url .= "&fields=".$field;
  }
  if (defined(@cats)) {
    $url .= "&allcats=NO";
    for my $cat (@cats) {
      if(!($cat =~ /^(blues|classical|country|data|folk|jazz|misc|newage|reggae|rock|soundtrack)$/)) {
		print STDERR "*unknown cat-type: $cat;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	    next;
	  }
	  $url .= "&cats=".$cat;
    }
  } else {
      $url .= "&allcats=YES";
  }
  print STDERR "**url-search: $url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
  my $data = get($url);
  @lines = split(/\n/,$data);
  my $liststart = 0 ;
  my $lastref;
  for my $line (@lines) {
    if($line =~ /^<h2>all categories<\/h2>$/) {
	  $liststart=1;
	} elsif ( $liststart == 1 && $line =~ /<table border=0>/){
	  print STDERR "**list start found;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
	  $liststart=2;
	} elsif ( $liststart == 2 && $line =~ /^<tr><td><a href="(.+)">(.+) \/ (.+)<\/a><br><br><\/tr>/ ) {
	  print STDERR "***list element found $url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 3);
	  if(!(defined($discs{$1}))) {
		$discs{$1} = [$2,$3];
		$lastref = undef;
	  } else {
	    print STDERR "*already got an disc, taking old one !: $line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	  }
	} elsif ( $liststart == 2 && $line =~ /^<tr><td><a href="(.+)">(.+) \/ (.+)<\/a><br><a href="(.+)"><font size=-1>\d+<\/font><\/a>/ ) {
	  print STDERR "***multilist element found $url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 3);
	  if(!(defined($discs{$1}))) {
		$discs{$1} = [$2,$3,$4];
		$lastref = $1;
	  } else {
	    print STDERR "*already got an disc, taking old one !: $line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	  }
	} elsif (defined($lastref) && $liststart == 2 && $line =~ /^<a href="(.+)"><font size=-1>\d+<\/font><\/a>/ ) {
	  print STDERR "***more multilist element found $url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 3);
	  if(!(defined($discs{$lastref}))) {
	    print STDERR "*but no lastref-element found $url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	  } else {
        push(@{$discs{$lastref}},$1);
	  }
	} elsif ( $liststart == 2 && $line =~ /^<\/table>$/) {
      print STDERR "**list end found;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
	  $liststart = 0;
	} elsif ($liststart == 2 ) {
      print STDERR "***unknown line-type, ignoring : $line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 3);
	}
  }
  return %discs;
}

#####
# Give this method a url (one of the disc-id-urls) and it will retrieve the disc-internal information
# returns a hash with the items of the cd. trackinfo is a array of the track information
#####
sub getdiscinfo {
  my $self = shift;
  my $url = shift;
  my %disc;

  print STDERR "**url-disc:$url;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
  my $data = get($url);
  if (!defined($data)) {
    print STDERR "*found no disc;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	return ;
  }
  $disc{url} = $url;
  @lines = split(/\n/,$data);
  $line = shift(@lines);
  while (!($line =~ /^<table width="100%" border="0" cellspacing="1" cellpadding="8" bgcolor="#FFFFFF"><tr><td>$/)) { #ignore until begin of data
    $line = shift(@lines);
  }
  print STDERR "**found start of data :$line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
  if ($lines[0] =~ /^<h2>(.+) \/ (.+)<\/h2>$/) {
	$disc{artist} = $1;
	$disc{cdname} = $2;
  } else {
    print STDERR "*format error(artist+cdname):$lines[0];\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
  }
  if ($lines[1] =~ /^tracks:\s*?(\d+)<br>$/) {
	$disc{tracks} = $1;
  } else {
    print STDERR "*format error(tracks):$lines[1];\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
  }
  if ($lines[2] =~ /^total time:\s*(\d+:\d+)<br>$/) {
	$disc{totaltime} = $1;
  } else {
    print STDERR "*format error(totaltime):$lines[2];\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
  }
  if ($lines[3] =~ /^year:\s*(\d*)<br>$/) {
	$disc{year} = $1;
  } else {
    print STDERR "*format error(year):$lines[3];\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
  }
  if ($lines[4] =~ /^genre:\s*(.*)<br>$/) {
	$disc{genre} = $1;
  } else {
    print STDERR "*format error(genre):$lines[4];\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
  }
  if(!defined($disc{artist})) {$disc{artist} = "";}
  if(!defined($disc{cdname})) {$disc{cdname} = "";}
  if(!defined($disc{year})) {$disc{year} = "";}
  if(!defined($disc{genre})) {$disc{genre} = "";}
  while (!($line =~ /^<table border=0>$/)) { #ignore until begin of tackinfo
	if ($line =~ /^<br><hr><center><table width="98%"><tr><td bgcolor="#E8E8E8"><pre>$/) {
      $line = shift(@lines);
	  while (!($line =~ /<\/pre><\/tr><\/td><\/table><\/center>/)) {
	    $disc{rest} .= $line."\n";
        $line = shift(@lines);
	  }
	}
    $line = shift(@lines);
    if (!defined($line)) {
	  $disc{trackinfo} = defined;
	  return %disc;  #break if not found beginning (empty entries)
	}
  }
  print STDERR "**found start of trackinfo:$line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
  $index = 1;
  for my $line (@lines) {
	if ($line =~ /^<br><br><\/td><\/tr>$/) {next;}    
	elsif ($line =~ /^<font size=small>.*?<\/font>/) {next;} # ignore ext-desc of a track
	elsif ($line =~ /^<tr><td valign=top> {0,1}$index\.<\/td><td valign=top> {0,1}(\d+:\d+)<\/td><td><b>(.+)<\/b>/) {
      print STDERR "***found track: $line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 3);
	  $disc{trackinfo}[$index-1]=[$2,$1];
	  $index++;
	} elsif ($line =~ /^<tr><td valign=top> \d+\.<\/td><td valign=top> (\d+:\d+)<\/td><td><b>(.+)<\/b>/) {
      print STDERR "*out of sync for trackinfo:$line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	} elsif ($line =~ /^<\/table>$/) {
      print STDERR "**found end of trackinfo & data: $line;\n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 2);
	} else {next;}

  }
  return %disc;


}
  
#####
# Give this method hash of found discs (%discs from getdiscs) and the user will be asked for selection.
# returns an array of urls - selected by the user
#####
sub ask4discurls {
  my $self = shift;
  my %discs = %{$_[0]};
  #my @keys = keys (%discs);
  my @keys = sort { $discs{$a}[0] cmp $discs{$b}[0] || $discs{$a}[1] cmp $discs{$b}[1]} keys %discs;   #sort for artists
  my @urls;
  
  if(!defined($keys[0])) {
    print STDERR "Sorry - no matching discs found\n";
	return 1;
  }
  #giving list 2 user
  for (my $i=0;$i<@keys;$i++) {
    print STDERR "$i) ".$discs{$keys[$i]}[0]." / ".$discs{$keys[$i]}[1];
	if (defined $discs{$keys[$i]}[2]) {
	  print STDERR " [".(@{$discs{$keys[$i]}} - 2)." alternatives]";
	}
	print STDERR "\n";
  }
  print STDERR "Select discs (space seperated numbers or <from>-<to>;alternatives by appending 'A' and alternate-number):\n";
  $userin = <STDIN>;
  chomp $userin;
  while($userin =~ /(\d+)A(\d+)-(\d+)A(\d+)/) {                                              # 23A2-42A3 - so with beginning alternatives
    if(!($1<$3)) {
      print STDERR "Ignoring $1-$3 ...";
    }
    my $tmpadd = $1."A".$2." ";
    for(my $i=$1+1;$i<=$3-1;$i++) {
      $tmpadd .= $i." ";
    }
	$tmpadd .= $3."A".$4;
    $userin =~ s/$1A$2-$3A$4/$tmpadd/;
  }
  while($userin =~ /(\d+)A(\d+)-(\d+)/) {                                              # 23A2-42 - so with beginning alternatives
    if(!($1<$3)) {
      print STDERR "Ignoring $1-$3 ...";
    }
    my $tmpadd = $1."A".$2." ";
    for(my $i=$1+1;$i<=$3;$i++) {
      $tmpadd .= $i." ";
    }
    $userin =~ s/$1A$2-$3/$tmpadd/;
  }
  while($userin =~ /(\d+)-(\d+)A(\d+)/) {                                              # 23-42A2 - so with beginning alternatives
    if(!($1<$2)) {
      print STDERR "Ignoring $1-$2 ...";
    }
    my $tmpadd = "";
    for(my $i=$1;$i<=$2-1;$i++) {
      $tmpadd .= $i." ";
    }
	$tmpadd .= $2."A".$3;
    $userin =~ s/$1-$2A$3/$tmpadd/;
  }
  while($userin =~ /(\d+)-(\d+)/) {                                              # 23-42 - so without alternatives
    if(!($1<$2)) {
      print STDERR "Ignoring $1-$2 ...";
    }
    my $tmpadd = "";
    for(my $i=$1;$i<=$2;$i++) {
      $tmpadd .= $i." ";
    }
    $userin =~ s/$1-$2/$tmpadd/;
  }
  @select = split (/ /,$userin);
  for my $cd (@select) {
    if ($cd =~ /^\d+$/ && defined($keys[$cd])) {
	  push(@urls,$keys[$cd]);
	} elsif ($cd =~ /^(\d+)A(\d+)$/ && $discs{$keys[$1]}[($2+2)]) {
	  push(@urls,$discs{$keys[$1]}[($2+2)]);
    } else {
      print STDERR "not defined '$cd' - ignoring!\n";
	}
  }
  return @urls;

}

#####
# Give this method disc-hash of (%disc from discinfo) and the user will be get a Data::Dumper-Output.
# returns nothing
#####
sub outdumper {
  if(!defined($disc{url})) {
    print STDERR "*no disc info \n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	return 1;
  }
  my $self = shift;
  my $disc = shift;
  print Dumper $disc;
}

#####
# Give this method disc-hash of (%disc from discinfo) and the user will be get a nice-to-read STDOUT
# returns nothing
#####
sub outstd {
  my $self = shift;
  my %disc = %{$_[0]};
  if(!defined($disc{url})) {
    print STDERR "*no disc info \n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	return 1;
  }
  print "DiscInfo:\n########\n";
  print "Artist:".$disc{artist}." - Album: ".$disc{cdname}."\n";
  print "Reference:".$disc{url}."\n";
  print "Total-Tracks:".$disc{tracks}." - Total-Time:".$disc{totaltime}."\n";
  print "Year:".$disc{year}." - Genre:".$disc{genre}."\n";
  if(defined($disc{rest})) {print "Comment:".$disc{rest}."\n";}
  print "Tracks:\n";
  for (my $i=0;$i<@{$disc{trackinfo}};$i++) {
	print 1+$i.") ".${$disc{trackinfo}}[$i][0]." (".${$disc{trackinfo}}[$i][1].")\n";
  }
}

#####
# Give this method disc-hash of (%disc from discinfo) and the user will be get a element in XML-Format accourding to example/cdcollection.dtd
# except of the XML-header, footer and root-tag
# returns nothing
#####
sub outxml {
  my $self = shift;
  my %disc = %{$_[0]};
  if(!defined($disc{url})) {
    print STDERR "*no disc info \n" if (defined $self->{ARG}->{DEBUG} && $self->{ARG}->{DEBUG} >= 1);
	return 1;
  }
  print "<cd>\n";
  print "\t<artist>".ascii2xml($disc{artist})."</artist>\n";
  print "\t<title>".ascii2xml($disc{cdname})."</title>\n";
  if (defined($disc{year})) {print "\t<year>".ascii2xml($disc{year})."</year>\n";}
  print "\t<tracklist>\n";
  for (my $i=0;$i<@{$disc{trackinfo}};$i++) {
	print "\t\t<track>".ascii2xml(${$disc{trackinfo}}[$i][0])."</track>\n";
  }
  print "\t</tracklist>\n";
  print "</cd>\n";
}
####
# gets a string and returns it in xml coding-stadart (&->&amp; ...)
####
sub ascii2xml {
  $ascii = $_[0];

  $ascii =~ s/&/&amp;/g;
  $ascii =~ s/</&lt;/g;
  $ascii =~ s/>/&gt;/g;
  $ascii =~ s/'/&apos;/g;
  $ascii =~ s/"/&quot;/g;
  
  return $ascii;
}

return 1;
__END__

=head1 NAME

WebService::FreeDB - retrieving entries from FreeDB by searching for keywords (artist,track,album,rest)

=head1 SYNOPSIS

    use WebService::FreeDB;

    # Create an Object
    $freedb = WebService::FreeDB->new();

    #  Get a list of all discs matching 'Fury in the Slaughterhouse'
    %discs = $cddb->getdiscs(
	    "Fury in the Slaughterhouse",
	    ['artist','rest']
    );

    # Asks user to select one or more of the found discs
    @selecteddiscs = $cddb->ask4discurls(\%discs);

    # Get a disc
    %discinfo = $cddb->getdiscinfo(@selecteddiscs[0]);

    # print disc-information to STDOUT - pretty nice formatted
    $cddb->outstd(\%discinfo);

=head1 DESCRIPTION

WebService::FreeDB uses a FreeDB web interface (default is www.freedb.org) for searching 
of CD Information. Using the webinterface, WebService::FreeDB searches for artist, song, album name
or the "rest field. 

The high level functions included in this modules makes it easy to search for an 
artist of a song, all songs of an artist, all CDs of an artist or whatever.

=head1 USING WebService::FreeDB

=over 6

=item B<How to work with WebService::FreeDB>

=item B<1. Creating a WebService::FreeDB object>

This has to be the first step

    my $cddb = WebService::FreeDB->new()

You can configure the behaviour of the Module giving new() optional parameters:

Usage is really simple. To set the debug level to 1, simply:

    my $cddb = WebService::FreeDB->new( DEBUG => 1 )

B<optional prameters>
B<DEBUG>: [0 to 3] - Debugging information,

C<0> is default (means no additional information), 3 gives a lot of stuff (hopefully) nobody needs.
All debug information goes to STDERR.

B<HOST>: FreeDB-Host where to connect to.

C<www.freedb.org> is default - has to have a webinterface - no normal FreeDB-Server !

B<PATH>: Path to the php-script (the webinterface)

C</freedb_search.php> is default - so working on www.freedb.org

B<DEFAULTVALUES>: Values with will be set for every request.

C<allfields=NO&grouping=none> is default, so the grouping feature is not supported until now.

=item B<2. Getting a list of all albums for keywords.>

Now we retrieve a list of CDs, which match to your keywords in given fields.
Available fields are C<artist,title,track,rest>.
Available categories are C<blues,classical,country,data,folk,jazz,misc,newage,reggae,rock,soundtrack>
For explanation see the webinterface.

    %discs = $cddb->getdiscs(
	"Fury in the Slaughterhouse",
	[qw( artist rest )]
    );

The returned hash includes as key the urls for retriving the concrete data and as
value a array of the artist,the album name followed by the alternative disc-urls

=item B<3. Selecting discs from the big %discs hash.>

After retrieving a huge list of possible matches we have to ask the user to select one or
more CDs for retrieval of the disc-data. 

C<@selecteddiscs = $cddb-E<gt>ask4discurls(\%discs);>

The function returns an array of urls after asking user. (using STDERR)
The user can select the discs by typing numbers and ranges (e.g. 23-42)


=item B<4. Retrieving the concrete disc informations>

This functions gets a url and returns a hash including all disc information.

C<%discinfo = $cddb-E<gt>getdiscinfo(@selecteddiscs[0]);>

So we have to call this function n-times if the user selects n cds.
The hash includes the following keys
C<url,artist,totaltime,genre,album,trackinfo,rest,tracks,year>
These are all string except trackinfo, this is a array of arrays.
Every of these small arrays represent a track: first its name , second its time.

Please keep an eye on track vs. length of the trackinfo array.
Some entries in FreeDB store an other number of tracks than they have stored !

=item B<5. print out disc information.>

Now the last step is to print the information to the user.

    $cddb->outdumper(\%discinfo); # Like Data::Dumper
    $cddb->outstd(\%discinfo); # nicely formatted to stdout
    $cddb->outxml(\%discinfo); # XML format

These 3 functions print a retrieved disc out.

The XML format outputs according to example/cdcollection.dtd this method
does not use every information (missing are total-time,tracktime,rest). I
think this is the point for starting your work: Take %discinfo and write
where ever you want.

=back

=head1 NOTICE

Be aware this module is in B<BETA> stage. 

=head1 AUTHOR

Copyright 2002-2003, Henning Mersch All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
Address bug reports and comments to: hm@mystical.de

=head1 BUGS

None known - but feel free to mail if you got some !

=head1 SEE ALSO

perl(1).

=cut

