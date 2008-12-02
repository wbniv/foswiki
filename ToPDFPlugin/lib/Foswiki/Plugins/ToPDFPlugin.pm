#!/usr/local/bin/perl -wI.
#
# This script Copyright (c) 2008 Impressive.media 
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

=pod

=head1 TWiki::Contrib::ToPDF

TWiki::Contrib::ToPDF - Displays TWiki page as PDF using html2pdf

=head1 DESCRIPTION

See the ToPDFPlugin.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package Foswiki::Contrib::ToPDFPlugin;

use strict;

use CGI;
use Foswiki::Func;
use Foswiki::UI::View;
use File::Temp qw( tempfile );
use File::Basename;
use Error qw( :try );
use URI::Escape;
use Encode;
use Encode::Encoding;
#use utf8;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev: 15468 $';

$RELEASE = 'Dakar';

$| = 1; # Autoflush buffers

our $query;
our %tree;
our %prefs;

=pod

=head2 _getRenderedView($webName, $topic)

Generates rendered HTML of $topic in $webName using Foswiki rendering functions and
returns it.
 
=cut

sub _getRenderedView {
   my ($webName, $topic) = @_;
   
   # Read topic data.
   my ($meta, $text) = Foswiki::Func::readTopic( $webName, $topic );
    
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      Foswiki::Func::redirectCgiQuery($query, $text);
   }
   $text =~ s/\%TOC({.*?})?\%//g; # remove Foswiki TOC
   #Expand and render the topic text
   $text = Foswiki::Func::expandCommonVariables(
                    $text, $topic, $webName, $meta);

   $text = Foswiki::Func::renderText($text);
   # Expand and render the template
   my $tmpl = Foswiki::Func::readTemplate( "viewprint", $Foswiki::cfg{Plugins}{ToPDF}{PrintTemplate} );
   $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $webName, $meta);
   $tmpl =~ s/%TEXT%/$text/g;
   $tmpl = Foswiki::Func::renderText($tmpl, $webName);
   
   return $tmpl;
}


=head2 _fixHtml($html)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modified html.

=cut

sub _fixHtml {
   my ($html, $topic, $webName, $refTopics) = @_;
   my $title = Foswiki::Func::expandCommonVariables($prefs{'title'}, $topic, $webName);
   $title = Foswiki::Func::renderText($title);
   $title =~ s/<.*?>//gs;

   # remove <nop> tags
   $html =~ s/<nop>//g;
   #remove TOC links, as they are represented as a linebreak
   $html =~ s/<a name="(.*?)"><\/a>//g;
   #remove toc links
   $html =~ s/<a href="#toc" class="tocLink">&uarr;<\/a>//g;

   # remove all page breaks
   # FIXME - why remove a forced page break? Instead insert a <!-- PAGE BREAK -->
   #         otherwise dangling </p> is not cleaned up
   $html =~ s/(<p(.*) style="page-break-before:always")/\n<!-- PAGE BREAK -->\n<p$1/gis;

   # remove %META stuff
   $html =~ s/%META:\w+{.*?}%//gs;

   # Prepend META tags for PDF meta info - may be redefined later by topic text
   my $meta = '<META NAME="AUTHOR" CONTENT="%REVINFO{format="$wikiusername"}%"/>'; # Specifies the document author.
   $meta .= '<META NAME="COPYRIGHT" CONTENT="%WEBCOPYRIGHT%"/>'; # Specifies the document copyright.
   $meta .= '<META NAME="DOCNUMBER" CONTENT="%REVINFO{format="r1.$rev - $date"}%"/>'; # Specifies the document number.
   $meta .= '<META NAME="GENERATOR" CONTENT="%WIKITOOLNAME% %WIKIVERSION%"/>'; # Specifies the application that generated the HTML file.
   # TODO: subject and keywords should be taken from ?! Maybe take web, topic as keywords
   #$meta .= '<META NAME="KEYWORDS" CONTENT="'. $prefs{'keywords'} .'"/>'; # Specifies document search keywords.
   $meta .= '<META NAME="SUBJECT" CONTENT="$topic"/>'; # Specifies document subject.
   $meta = Foswiki::Func::expandCommonVariables($meta, $topic, $webName);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   $meta = Foswiki::Func::renderText($meta);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   # FIXME - renderText converts the <META> tags to &lt;META&gt;
   # if the CONTENT contains anchor tags (trying to be XHTML compliant)
   $meta =~ s/&lt;/</g;
   $meta =~ s/&gt;/>/g;

   # SMELL: Shouldn`t this be up to the user, if he wants h1 or not?
   # Insert an <h1> header if one isn't present
   # and a target (after the <h1>) for this topic so it gets a bookmark
   #if ($html !~ /<h1>/is) {
   #   $html = "<h1>$topic</h1><a name=\"$topic\"> </a>$html";
   #} else {
   #   $html = "<a name=\"$topic\"> </a>$html";
   #}
   $html = "<head><title>$title</title>\n$meta</head>\n<body>$html</body>";

   # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
   # convert some common HTML4.x elements to similar HTML3.2 elements
   # TODO: do we need this for html2pdf?
   #$html =~ s/&ndash;/&shy;/g;
   #$html =~ s/&[lr]dquo;/"/g;
   #$html =~ s/&[lr]squo;/'/g;
   #$html =~ s/&brvbar;/|/g;

   # convert FoswikiNewLinks to normal text
   $html =~ s/<span class="foswikiNewLink".*?>([\w\s]+)<.*?\/span>/$1/gs;

   # Fix the image tags to use hard-disk path rather than relative url paths for
   # images.  Needed if wiki requires authentication like SSL client certifcates.
   # Fully qualify any unqualified URLs (to make it portable to another host)
   my $url = Foswiki::Func::getUrlHost();
   my $pdir = Foswiki::Func::getPubDir();
   my $purlp = Foswiki::Func::getPubUrlPath();

   $html =~ s!<img(.*?) src="($url)?$purlp!<img$1 src="$pdir!sgi;
   # url encoding string, as we use them as local paths and that would e..g fail for umluats
   $html =~ s!<img(.*?) src="(.*?)"!"<img$1 src=\"".uri_unescape($2).'"'!esgi;
   $html =~ s/<a(.*?) href="\//<a$1 href="$url\//sgi;
   # link internally if we include the topic
   for my $wikiword (@$refTopics) {
      $url = Foswiki::Func::getScriptUrl($webName, $wikiword, 'view');
      $html =~ s/([\'\"])$url$1/$1#$wikiword$1/g; # not anchored
      $html =~ s/$url(#\w*)/$1/g; # anchored
   }

   # change <li type=> to <ol type=> 
   $html =~ s/<ol>\s+<li\s+type="([AaIi])">/<ol type="$1">\n<li>/g;
   $html =~ s/<li\s+type="[AaIi]">/<li>/g;

   return $html;
}

=pod

=head2 viewPDF

This is the core method to convert the current page into PDF format.

=cut

sub viewPDF {
   my $session = shift;
   # using Foswiki::UI so i have a sessin object. There had been some issues with the user / caller of the script and
   # with the old implementation. But there have also been thoughts of the Foswiki::UI way being to "heavy" for this puporse
   # SMELL: maybe Foswiki::UI should not be used. RestHandler is an option
   
   # this is for letting Foswiki::Func functions work properly ( as in plugin scope )
   $Foswiki::Plugins::SESSION=$session;
   # initialize module wide variables
   my $query = $session->{cgiQuery};

   # Initialize Foswiki
   my $topic = $session->{topicName};
   my $webName = $session->{webName};
   my $userName = $session->{user}->wikiName();
   my $theUrl = $query->url;

   # Check for existence
   Foswiki::Func::redirectCgiQuery($query,
         Foswiki::Func::getOopsUrl($webName, $topic, "oopsmissing"))
      unless Foswiki::Func::topicExists($webName, $topic);

   my @webTopicPairs;
   # FEATURE: viewPDF should get a list of topics, which have to be rendered to one PDF.
   #  This could be e.g. a parent topic with all its childs or just a set of topics out of diffrent webs etc. 
   #  Let this be as "powerfull" as possible. SMELL this feature is interferring with PublishAddon
   # this is a dummy, as we only support one, the current topic
   $webTopicPairs[0]{'web'} = $webName;
   $webTopicPairs[0]{'topic'} = $topic;
   my @topicHTMLfiles = _renderTopics($session,@webTopicPairs);
   my $inputFile = $topicHTMLfiles[0]; 
   # we use he first topic tmp file as pdf name, so something like html2pdfXXXX will be the result, 
   # nice for debugging if needed. outputFilen is not allowed to have a fileext as it will be escaped
   # .pdf will be attached to the filename by html2pdf automatically
   my($outputFilename, $outputDir, $suffix) = fileparse($inputFile,".html");
   # TODO: maybe this should be changed latter, to process all html files. Yet, this is a hack for supporting only the current topic
   my $finalPDF = $outputDir.$outputFilename.".pdf";
   # the command to be run to convert our html file(s) to pdf, BACKEND
   # we pass webName, topic and username to be used as paramaters in header/footer.
   # FEATURE: maybe construct the header/footer out of Foswiki topics or similar, so they can be customized user-friendlier
   my $pubDir = Foswiki::Func::getPubDir();
   # SMELL the path to the php binary should be configureable or the script shoudl depend on it to be in PATH
   
   #my $Cmd = "/usr/bin/php $pubDir/System/ToPDFPlugin/topdf.php $inputFile $outputFilename $outputDir \"$webName/$topic\" \"$userName\"";
   #have to be utf8 to let html2pdf work properly. They will be converted to the specified encoding in html2pdf later.
   my $utf8topic = encode("utf8",$topic);
   my $utf8webName = encode("utf8",$webName);
   my $utf8userName = encode("utf8",$userName);
   my $headerFile = _getHeaderFile();
   my $footerFile = _getFooterFile();
   my $Cmd = "/usr/bin/php $pubDir/System/ToPDFPlugin/topdf.php $inputFile $outputFilename $outputDir \"$utf8webName/$utf8topic\" \"$utf8userName\" \"$headerFile\" \"$footerFile\"";
   
   # actually run the converting command
   system($Cmd);
   if ($? == -1) {
      die "Failed to run html2pdf ($Cmd): $!\n";
   }
   elsif ($? & 127) {
      printf STDERR "child died with signal %d, %s coredump\n",
         ($? & 127),  ($? & 128) ? 'with' : 'without';
      die "Conversion failed: '$!'";
   }
   else {
      printf STDERR "child exited with value %d\n", $? >> 8 unless $? >> 8 == 0;
   }

   #  output the HTML header and the output of HTMLDOC
   my $cd = "filename=${webName}_$topic.";
   print CGI::header( -TYPE => 'application/pdf',-Content_Disposition => $cd.'pdf');   
   open my $ofh, '<', $finalPDF or die "I cannot open $finalPDF for reading, cap'n: $!";
   while(<$ofh>){
	  print;
   }
   close $ofh;

   # Cleaning up temporary files
   unlink $finalPDF;
   unlink @topicHTMLfiles;
}

sub _renderTopic {
   my ($session,$webName,$topic) = @_;
   my $htmlData = _getRenderedView($webName, $topic);
   
   # clean up the HTML, remove things not working with html2pdf backend
   # SMELL: really really important and critical function, should be thought especially well
   $htmlData = _fixHtml($htmlData, $topic, $webName);

   # The data returned also includes the header. Remove it.
   $htmlData =~ s|.*(<!DOCTYPE)|$1|s;
   return $htmlData;
}

sub _renderTopics {
   my($session,@webTopicPairs) = @_; 
   my @topicHTMLfiles;
   foreach my $webTopicPair (@webTopicPairs) {
	my ($webName, $topic) = ($webTopicPair->{'web'},$webTopicPair->{'topic'}); 
	my $topicAsHTML = _renderTopic($session,$webName,$topic);

	 # Save this to a temp file for converting by command line
	 my ($cfh, $newFile) = tempfile('html2pdfXXXX',
						  DIR => "/tmp",
						  UNLINK => 0, # DEBUG
						  SUFFIX => '.html');
	 @topicHTMLfiles = (@topicHTMLfiles,$newFile);
         # throw in our content
	 print $cfh $topicAsHTML; 
	 close($cfh);
   }
   return @topicHTMLfiles;
}

sub _getHeaderFile {
	my($session) = @_; 
    my ($cfh, $path ) = tempfile('html2pdfHeaderXXXX',
                          DIR => "/tmp",
                          UNLINK => 0,
                          SUFFIX => '.html');
   my $topicAsHTML = _renderTopic($session,"System","ToPDFPluginHeader");
   print $cfh $topicAsHTML; 
   close($cfh);
   return $path;
}

sub _getFooterFile {
    my($session) = @_; 
    my ($cfh, $path ) = tempfile('html2pdfFooterXXXX',
                          DIR => "/tmp",
                          UNLINK => 0,
                          SUFFIX => '.html');
   my $topicAsHTML = _renderTopic($session,"System","ToPDFPluginFooter");
   print $cfh $topicAsHTML; 
   close($cfh);
   return $path;
}

1;
# vim:et:sw=3:ts=3:tw=0
