#!/usr/local/bin/perl -wI.
#
# GenPDF.pm (converts TWiki page to PDF using HTMLDOC)
#    (based on PrintUsingPDF pdf script)
#
# This script Copyright (c) 2005 Cygnus Communications
# and distributed under the GPL (see below)
#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
# Additional mess by Patrick Ohl - Biomax Bioinformatics AG
# January 2003
# fixes for TWiki 4.2 (c) 2008 SvenDowideit@fosiki.com
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

=head1 TWiki::Contrib::GenPDF

TWiki::Contrib::GenPDF - Displays TWiki page as PDF using HTMLDOC

=head1 DESCRIPTION

See the GenPDFAddOn TWiki topic for a description.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package TWiki::Contrib::GenPDF;

use strict;

use CGI;
use TWiki::Func;
use TWiki::UI::View;
use File::Temp qw( tempfile );
use Error qw( :try );

use vars qw( $VERSION $RELEASE );

# This should always be $Rev: 16963 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 16963 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$| = 1; # Autoflush buffers

our $query;
our %tree;
our %prefs;

=pod

=head2 _fixTags($text)

Expands tags in the passed in text to the appropriate value in the preferences hash and
returns modified $text.
 
=cut

sub _fixTags {
   my ($text) = @_;

   $text =~ s|%GENPDFADDON_BANNER%|$prefs{'banner'}|g;
   $text =~ s|%GENPDFADDON_TITLE%|$prefs{'title'}|g;
   $text =~ s|%GENPDFADDON_SUBTITLE%|$prefs{'subtitle'}|g;
   
   return $text;
}


=pod

=head2 _getRenderedView($webName, $topic)

Generates rendered HTML of $topic in $webName using TWiki rendering functions and
returns it.
 
=cut

sub _getRenderedView {
   my ($webName, $topic) = @_;

   my $text = TWiki::Func::readTopicText($webName, $topic);
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      return "Sorry, this topic is not accessible at this time."
         if $prefs{'recursive'}; # no point spoiling _everything_
      TWiki::Func::redirectCgiQuery($query, $text);
   }

   my $skin = $prefs{'cover'}.','.$prefs{'skin'};
   my $tmpl = TWiki::Func::readTemplate($prefs{'template'}, $skin) || '%TEXT%';

   my( $start, $end );
   if( $tmpl =~ m/^(.*)%TEXT%(.*)$/s ) {
       my @starts = split( /%STARTTEXT%/, $1 );
       if ( $#starts > 0 ) {
           # we know that there is something before %STARTTEXT%
           $start = $starts[0];
           $text = $starts[1] . $text;
       } else {
           $start = $1;
       }
       my @ends = split( /%ENDTEXT%/, $2 );
       if ( $#ends > 0 ) {
           # we know that there is something after %ENDTEXT%
           $text .= $ends[0];
           $end = $ends[1];
       } else {
           $end = $2;
       }
   } else {
       my @starts = split( /%STARTTEXT%/, $tmpl );
       if ( $#starts > 0 ) {
           # we know that there is something before %STARTTEXT%
           $start = $starts[0];
           $text = $starts[1];
       } else {
           $start = $tmpl;
           $text = '';
       }
       $end = '';
   }

   
   $text =~ s/\%TOC({.*?})?\%//g; # remove TWiki TOC
   $text = TWiki::Func::expandCommonVariables($start.$text.$end, $topic, $webName);
   $text = TWiki::Func::renderText($text);

   return $text;
}


=pod

=head2 _extractPdfSections

Removes the text not found between PDFSTART and PDFSTOP HTML
comments. PDFSTART and PDFSTOP comments must appear in pairs.
If PDFSTART is not included in the text, the entire text is
return (i.e. as if PDFSTART was at the beginning and PDFSTOP
was at the end).

=cut

sub _extractPdfSections {
   my ($text) = @_;

   # If no start tag, just return everything
   return $text if ($text !~ /<!--\s*PDFSTART\s*-->/);

   my $output = "";
   while ($text =~ /(.*?)<!--\s*PDFSTART\s*-->(.*?)<!--\s*PDFSTOP\s*-->/sg) {
      $output .= $2;
   }
   return $output;
}

=pod

=head2 _getHeaderFooterData($webName)

If header/footer topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.
 
=cut

sub _getHeaderFooterData {
   my ($webName) = @_;

   # Get the header/footer data (if it exists)
   my $text = "";
   my $topic = $prefs{'hftopic'};
   # Get a topic name without any whitespace
   $topic =~ s|\s||g;
   if ($prefs{'hftopic'}) {
      $text = TWiki::Func::readTopicText($webName, $topic);
   }
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      TWiki::Func::redirectCgiQuery($query, $text);
   }

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $text = _extractPdfSections($text);
   $text = _fixTags($text);

   my $output = "";
   # Expand common variables found between quotes. We have to jump through this loop hoop
   # as the variables to expand occur inside html comments so just expanding variables in
   # the full text doesn't do anything
   for my $line (split(/(?=<)/, $text)) {
      if ($line =~ /([^"]*")(.*)("[^"]*)/g) {
         my $start = $1;
         my $var = $2;
         my $end = $3;
         # Expand common variables and render
         #print STDERR "var = '$var'\n"; #DEBUG
         $var = TWiki::Func::expandCommonVariables($var, $topic, $webName);
         $var = TWiki::Func::renderText($var);
         $var =~ s/<.*?>|\n|\r//gs; # htmldoc can't use HTML tags in headers/footers
         #print STDERR "var = '$var'\n"; #DEBUG
         $output .= $start . $var . $end;
      }
      else {
         $output .= $line;
      }
   }

   return $output;
}


=pod

=head2 _createTitleFile($webName)

If title page topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.

=cut

sub _createTitleFile {
   my ($webName) = @_;

   my $text = '';
   my $topic = $prefs{'titletopic'};
   # Get a topic name without any whitespace
   $topic =~ s|\s||g;
   # Get the title topic (if it exists)
   if ($prefs{'titletopic'}) {
      $text .= TWiki::Func::readTopicText($webName, $topic);
   }
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      TWiki::Func::redirectCgiQuery($query, $text);
   }

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $text = _extractPdfSections($text);
   $text = _fixTags($text);

   # Now render the rest of the topic
   $text = TWiki::Func::expandCommonVariables($text, $topic, $webName);
   $text = TWiki::Func::renderText($text);

   # FIXME - send to _fixHtml
   # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
   # convert some common HTML4.x elements to similar HTML3.2 elements
   $text =~ s/&ndash;/&shy;/g;
   $text =~ s/&[lr]dquo;/"/g;
   $text =~ s/&[lr]squo;/'/g;
   $text =~ s/&brvbar;/|/g;

   # convert twikiNewLinks to normal text
   # FIXME - should this be a preference? - should use setPreferencesValue($name, $val) to set NEWTOPICLINK
   # BUG: this will match _everything_ from the first open span, to the last end span, losing alot of content.
   #$text =~ s/<span class="twikiNewLink".*?>([\w\s]+)<.*?\/span>/$1/gs;

   # Fix the image tags to use hard-desk path range than url paths.
   # This is needed in case wiki requires read authentication like SSL client
   # certificates.
   # Fully qualify any unqualified URLs (to make it portable to another host)
   my $url = TWiki::Func::getUrlHost();
   my $pdir = TWiki::Func::getPubDir();
   my $purlp = TWiki::Func::getPubUrlPath();

   $text =~ s!<img(.*?) src="($url)?$purlp!<img$1 src="$pdir\/!sgi;
   $text =~ s/<a(.*?) href="(?!#)\//<a$1 href="$url\//sgi;

   # Save it to a file
   my ($fh, $name) = tempfile('GenPDFAddOnXXXXXXXXXX',
                               DIR => File::Spec->tmpdir(),
	                       SUFFIX => '.html');
   open $fh, ">$name";

   print $fh $text;

   close $fh; 
   return $name;
}


=pod

=head2 _shiftHeaders($html)

Functionality from original PDF script.

=cut

sub _shiftHeaders{
   my ($html) = @_;

   if ($prefs{'shift'} =~ /^[+-]?\d+$/) {
      my $newHead;
      # You may want to modify next line if you do not want to shift _all_ headers.
      # I leave for example all header that contain a digit folowed by a point.
      # Look like this:
      # $html =~ s&<h(\d)>((?:(?!(<h\d>|\d\.)).)*)</h\d>&'<h'.($newHead = ($1+$sh)>6?6:($1+$sh)<1?1:($1+$sh)).'>'.$2.'</h'.($newHead).'>'&gse;
      # NOTE - htmldoc allows headers up to <h15>
      $html =~ s|<h(\d)>((?:(?!<h\d>).)*)</h\d>|'<h'.($newHead = ($1+$prefs{'shift'})>15?15:($1+$prefs{'shift'})<1?1:($1+$prefs{'shift'})).'>'.$2.'</h'.($newHead).'>'|gsei;
   }

   return $html;
}

=pod

=head2 _fixHtml($html)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modified html.

=cut

sub _fixHtml {
   my ($html, $topic, $webName, $refTopics) = @_;
   my $title = TWiki::Func::expandCommonVariables($prefs{'title'}, $topic, $webName);
   $title = TWiki::Func::renderText($title);
   $title =~ s/<.*?>//gs;
   #print STDERR "title: '$title'\n"; # DEBUG

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $html = _extractPdfSections($html);

   # remove <nop> tags
   $html =~ s/<nop>//g;

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
   $meta .= '<META NAME="KEYWORDS" CONTENT="'. $prefs{'keywords'} .'"/>'; # Specifies document search keywords.
   $meta .= '<META NAME="SUBJECT" CONTENT="'. $prefs{'subject'} .'"/>'; # Specifies document subject.
   $meta = TWiki::Func::expandCommonVariables($meta, $topic, $webName);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   $meta = TWiki::Func::renderText($meta);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   # FIXME - renderText converts the <META> tags to &lt;META&gt;
   # if the CONTENT contains anchor tags (trying to be XHTML compliant)
   $meta =~ s/&lt;/</g;
   $meta =~ s/&gt;/>/g;
   #print STDERR "meta: '$meta'\n"; # DEBUG

   $html = _shiftHeaders($html);

   # Insert an <h1> header if one isn't present
   # and a target (after the <h1>) for this topic so it gets a bookmark
   if ($html !~ /<h1>/is) {
      $html = "<h1>$topic</h1><a name=\"$topic\"> </a>$html";
   } else {
      $html = "<a name=\"$topic\"> </a>$html";
   }
   # htmldoc reads <title> for PDF Title meta-info
   $html = "<head><title>$title</title>\n$meta</head>\n<body>$html</body>";

   # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
   # convert some common HTML4.x elements to similar HTML3.2 elements
   $html =~ s/&ndash;/&shy;/g;
   $html =~ s/&[lr]dquo;/"/g;
   $html =~ s/&[lr]squo;/'/g;
   $html =~ s/&brvbar;/|/g;

   # convert twikiNewLinks to normal text
   # FIXME - should this be a preference? - should use setPreferencesValue($name, $val) to set NEWTOPICLINK
   # BUG: this will match _everything_ from the first open span, to the last end span, losing alot of content.
   #$html =~ s/<span class="twikiNewLink".*?>([\w\s]+)<.*?\/span>/$1/gs;

   # Fix the image tags to use hard-disk path rather than relative url paths for
   # images.  Needed if wiki requires authentication like SSL client certifcates.
   # Fully qualify any unqualified URLs (to make it portable to another host)
   my $url = TWiki::Func::getUrlHost();
   my $pdir = TWiki::Func::getPubDir();
   my $purlp = TWiki::Func::getPubUrlPath();

   $html =~ s!<img(.*?) src="($url)?$purlp!<img$1 src="$pdir\/!gi;
   $html =~ s/<a(.*?) href="\//<a$1 href="$url\//gi;
   # link internally if we include the topic
   for my $wikiword (@$refTopics) {
      $url = TWiki::Func::getScriptUrl($webName, $wikiword, 'view');
      $html =~ s/([\'\"])$url/$1#$wikiword/g; # not anchored
      $html =~ s/$url(#\w*)/$1/g; # anchored
   }

   # change <li type=> to <ol type=> 
   $html =~ s/<ol>\s+<li\s+type="([AaIi])">/<ol type="$1">\n<li>/g;
   $html =~ s/<li\s+type="[AaIi]">/<li>/g;

   return $html;
}

=pod

=head2 _getPrefs($query)

Creates a hash with the various preference values. For each preference key, it will set the
value first to the one supplied in the URL query. If that is not present, it will use the TWiki
preference value, and if that is not present and a value is needed, it will use a default.

See the GenPDFAddOn topic for a description of the possible preference values and defaults.

=cut

sub _getPrefs {
   # HTMLDOC location
   # $TWiki::htmldocCmd must be set in TWiki.cfg

  use constant BANNER => "";
  use constant TITLE => "";
  use constant SUBTITLE => "";
  use constant HEADERTOPIC => "";
  use constant TITLETOPIC => "";
  use constant SKIN => "pattern";
  use constant COVER => "print";
  use constant TEMPLATE => "view";
  use constant RECURSIVE => undef;
  use constant FORMAT => "pdf14";
  use constant TOCLEVELS => 5;
  use constant PAGESIZE => "a4";
  use constant ORIENTATION => "portrait";
  use constant WIDTH => 860;
  use constant HEADERSHIFT => 0;
  use constant KEYWORDS => '%FORMFIELD{"KeyWords"}%';
  use constant SUBJECT => '%FORMFIELD{"TopicHeadline"}%';
  use constant TOCHEADER => "...";
  use constant TOCFOOTER => "..i";
  use constant HEADER => undef;
  use constant FOOTER => undef;
  use constant HEADFOOTFONT => "";
  use constant HEADFOOTSIZE => undef;
  use constant BODYIMAGE => "";
  use constant LOGOIMAGE => "";
  use constant NUMBEREDTOC => undef;
  use constant DUPLEX => undef;
  use constant PERMISSIONS => undef;
  use constant MARGINS => undef;
  use constant BODYCOLOR => undef;
  use constant STRUCT => 'book';


   # header/footer topic
   $prefs{'hftopic'} = $query->param('pdfheadertopic') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADERTOPIC") || HEADERTOPIC;

   # title topic
   $prefs{'titletopic'} = $query->param('pdftitletopic') || TWiki::Func::getPreferencesValue("GENPDFADDON_TITLETOPIC") || TITLETOPIC;

   $prefs{'banner'} = $query->param('pdfbanner') || TWiki::Func::getPreferencesValue("GENPDFADDON_BANNER");
   $prefs{'banner'} = BANNER unless defined $prefs{'banner'};

   $prefs{'title'} = $query->param('pdftitle') || TWiki::Func::getPreferencesValue("GENPDFADDON_TITLE");
   $prefs{'title'} = TITLE unless defined $prefs{'title'};

   $prefs{'subtitle'} = $query->param('pdfsubtitle') || TWiki::Func::getPreferencesValue("GENPDFADDON_SUBTITLE");
   $prefs{'subtitle'} = SUBTITLE unless defined $prefs{'subtitle'};

   $prefs{'keywords'} = $query->param('pdfkeywords') || TWiki::Func::getPreferencesValue("GENPDFADDON_KEYWORDS") || KEYWORDS;

   $prefs{'subject'} = $query->param('pdfsubject') || TWiki::Func::getPreferencesValue("GENPDFADDON_SUBJECT") || SUBJECT;

   # get skin path based on urlparams and genpdfaddon settings
   $prefs{'skin'} = $query->param('skin') || TWiki::Func::getPreferencesValue("GENPDFADDON_SKIN") || SKIN;
   $prefs{'cover'} = $query->param('cover') || TWiki::Func::getPreferencesValue("GENPDFADDON_COVER") || COVER;

   # get view template
   $prefs{'template'} = $query->param('template') || TWiki::Func::getPreferencesValue('VIEW_TEMPLATE') || TEMPLATE;

   # get htmldoc structure mode
   $prefs{'struct'} = $query->param('pdfstruct') || TWiki::Func::getPreferencesValue('GENPDFADDON_MODE') || STRUCT;
   $prefs{'struct'} = STRUCT unless $prefs{'struct'} =~ /^(book|webpage|continuous)$/o;

   # Get TOC header/footer. Set to default if nothing useful given
   $prefs{'tocheader'} = $query->param('pdftocheader') || TWiki::Func::getPreferencesValue("GENPDFADDON_TOCHEADER") || '';
   $prefs{'tocheader'} = TOCHEADER unless ($prefs{'tocheader'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);

   $prefs{'tocfooter'} = $query->param('pdftocfooter') || TWiki::Func::getPreferencesValue("GENPDFADDON_TOCFOOTER") || '';
   $prefs{'tocfooter'} = TOCFOOTER unless ($prefs{'tocfooter'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);

   # Get some other parameters and set reasonable defaults unless not supplied
   $prefs{'format'} = $query->param('pdfformat') || TWiki::Func::getPreferencesValue("GENPDFADDON_FORMAT") || '';
   $prefs{'format'} = FORMAT unless ($prefs{'format'} =~ /^(html(sep)?|ps([123])?|pdf(1[1234])?)$/);

   $prefs{'size'} = $query->param('pdfpagesize') || TWiki::Func::getPreferencesValue("GENPDFADDON_PAGESIZE") || '';
   $prefs{'size'} = PAGESIZE unless ($prefs{'size'} =~ /^(letter|legal|a4|universal|(\d+x\d+)(pt|mm|cm|in))$/);

   $prefs{'orientation'} = $query->param('pdforientation') || TWiki::Func::getPreferencesValue("GENPDFADDON_ORIENTATION") || '';
   $prefs{'orientation'} = ORIENTATION unless ($prefs{'orientation'} =~ /^(landscape|portrait)$/);

   $prefs{'headfootsize'} = $query->param('pdfheadfootsize') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADFOOTSIZE") || '';
   $prefs{'headfootsize'} = HEADFOOTSIZE unless ($prefs{'headfootsize'} =~ /^\d+$/);

   $prefs{'header'} = $query->param('pdfheader') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADER") || '';
   $prefs{'header'} = HEADER unless ($prefs{'header'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);

   $prefs{'footer'} = $query->param('pdffooter') || TWiki::Func::getPreferencesValue("GENPDFADDON_FOOTER") || '';
   $prefs{'footer'} = FOOTER unless ($prefs{'footer'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);

   $prefs{'headfootfont'} = $query->param('pdfheadfootfont') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADFOOTFONT") || '';
   $prefs{'headfootfont'} = HEADFOOTFONT unless ($prefs{'headfootfont'} =~
      /^(times(-roman|-bold|-italic|bolditalic)?|(courier|helvetica)(-bold|-oblique|-boldoblique)?)$/);

   $prefs{'width'} = $query->param('pdfwidth') || TWiki::Func::getPreferencesValue("GENPDFADDON_WIDTH") || '';
   $prefs{'width'} = WIDTH unless ($prefs{'width'} =~ /^\d+$/);

   $prefs{'toclevels'} = $query->param('pdftoclevels');
   $prefs{'toclevels'} = TWiki::Func::getPreferencesValue("GENPDFADDON_TOCLEVELS") unless (defined($prefs{'toclevels'}) && ($prefs{'toclevels'} =~ /^\d+$/));
   $prefs{'toclevels'} = TOCLEVELS unless (defined($prefs{'toclevels'}) && ($prefs{'toclevels'} =~ /^\d+$/));

   $prefs{'bodycolor'} = $query->param('pdfbodycolor') || TWiki::Func::getPreferencesValue("GENPDFADDON_BODYCOLOR") || '';
   $prefs{'bodycolor'} = BODYCOLOR unless ($prefs{'bodycolor'} =~ /^[0-9a-fA-F]{6}$/);

   # Anything results in true (use 0 to turn these off or override the preference)
   $prefs{'recursive'} = $query->param('pdfrecursive') || TWiki::Func::getPreferencesValue("GENPDFADDON_RECURSIVE") || RECURSIVE || '';

   $prefs{'bodyimage'} = $query->param('pdfbodyimage') || TWiki::Func::getPreferencesValue("GENPDFADDON_BODYIMAGE") || BODYIMAGE;

   $prefs{'logoimage'} = $query->param('pdflogoimage') || TWiki::Func::getPreferencesValue("GENPDFADDON_LOGOIMAGE") || LOGOIMAGE;

   $prefs{'numbered'} = $query->param('pdfnumberedtoc') || TWiki::Func::getPreferencesValue("GENPDFADDON_NUMBEREDTOC") || NUMBEREDTOC || '';

   $prefs{'duplex'} = $query->param('pdfduplex') || TWiki::Func::getPreferencesValue("GENPDFADDON_DUPLEX") || DUPLEX || '';

   $prefs{'shift'} = $query->param('pdfheadershift') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADERSHIFT") || HEADERSHIFT;

   $prefs{'permissions'} = $query->param('pdfpermissions') || TWiki::Func::getPreferencesValue("GENPDFADDON_PERMISSIONS") || PERMISSIONS || '';
   $prefs{'permissions'} = join(',', grep(/^(all|annotate|copy|modify|print|no-annotate|no-copy|no-modify|no-print|none)$/,
      split(/,/, $prefs{'permissions'})));

   my @margins = grep(/^(top|bottom|left|right):\d+(\.\d+)?(cm|mm|in|pt)?$/, split(',', ($query->param('pdfmargins') || TWiki::Func::getPreferencesValue("GENPDFADDON_MARGINS") || MARGINS || '')));
   for (@margins) {
      my ($key,$val) = split(/:/);
      $prefs{$key} = $val;
   }
   #for my $key (keys %prefs) { print STDERR "$key = $prefs{$key}\n"; } #DEBUG
}

=pod

=head2 viewPDF

This is the core method to convert the current page into PDF format.

=cut

sub viewPDF {
   open(STDERR, ">>$TWiki::cfg{DataDir}/error.log"); # redirect errors to a log file

   # initialize module wide variables
   $query = new CGI;
   %tree = ();
   %prefs = ();

   # Initialize TWiki
   my $thePathInfo = $query->path_info(); 
   my $theRemoteUser = $query->remote_user();
   my $theTopic = $query->param('topic');
   my $theUrl = $query->url;

   my($topic, $webName, $scriptUrlPath, $userName) = 
      TWiki::initialize($thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query);

   # Get preferences
   _getPrefs($query);

   # Set a default skin in the query
   $query->param('skin', $prefs{'skin'});
   $query->param('cover', $prefs{'cover'});

   # Check for existence
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $topic, "oopsmissing"))
      unless TWiki::Func::topicExists($webName, $topic);
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $prefs{'hftopic'}, "oopscreatenewtopic"))
      unless TWiki::Func::topicExists($webName, $prefs{'hftopic'});
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $prefs{'titletopic'}, "oopscreatenewtopic"))
      unless TWiki::Func::topicExists($webName, $prefs{'titletopic'});

   # Get header/footer data
   my $hfData = _getHeaderFooterData($webName);

   my $fgrepCmd;
   my $htmldocCmd;
   if( defined $TWiki::cfg{DataDir} ) {
       # TWiki-4 or more recent
       $fgrepCmd = $TWiki::cfg{RCS}{FgrepCmd};
       $htmldocCmd = $TWiki::cfg{Extensions}{GenPDFAddOn}{htmldocCmd};
   } else {
       # Cairo or earlier
       $fgrepCmd = $TWiki::fgrepCmd;
       $htmldocCmd = $TWiki::htmldocCmd;
   }

   die "Path to htmldoc command not defined" unless $htmldocCmd;

   if ($prefs{'recursive'}) {
      # Include all descendents of this topic
      use Cwd 'cwd';
      my $cwd = cwd; # we need to chdir back after searching

      # Get a list of possibilities (all files in the web)
      chdir(TWiki::Func::getDataDir()."/$webName");
      opendir(DIR, ".") or die "$!";
      my @files = grep { /\.txt$/ && -f "$_" } readdir(DIR);
      closedir DIR;
      #for (@files) { print STDERR "file: '$_'\n"; } # DEBUG
      #print STDERR scalar @files," files found\n"; # DEBUG

      # Now build a hash of arrays mapping children to parents
      # Eg. $tree{$parent} = @children
      ($fgrepCmd) = split(/ /, $fgrepCmd); # only want the /path/to/command portion
      while (@files) {
         my @search = splice(@files, 0, 512); # only search 512 files at a time
         unshift @search, '%META:TOPICPARENT{'; #}
         # this is basically ripped straight out of TWiki::readFromProcessArray
         # This code follows the safe pipe construct found in perlipc(1).
         my $pipe;
         my $pid = open $pipe, '-|';
         my @data;
         if ($pid) {       # parent
            @data = map { chomp $_; $_ } <$pipe>; # remove newline characters.
            close $pipe;
         } else {
            exec { $fgrepCmd } $fgrepCmd, @search;
            # Usually not reached.
            exit 127;
         }
         #print STDERR scalar @data, " files have parent topics\n"; # DEBUG
         for (@data) {
            #print STDERR "data: '$_'\n"; # DEBUG
            my $tainted = $_;
            $tainted =~ /(\w+).txt:.*?name=\"(\w+)\"/ && do {
               push @{ $tree{$2} }, $1;
               #push @{ $tree{$parent} }, $child;
            }
         }
      }
      chdir($cwd); # return to previous working dir
   }

   # Do a recursive depth first walk through the ancestors in the tree
   # sub is defined here for clarity
   sub _depthFirst {
      my $parent = shift;
      my $topics = shift; # ref to @topics
      # the grep gets around a perl dereferencing bug when using strict refs
      my @children = grep { $_; } @{ $tree{$parent} };
      for ( sort @children ) {
         #print STDERR "new child of $parent: '$_'\n"; # DEBUG
         push @$topics, $_;
         if (defined $tree{$_}) {
            # this child is also a parent so bring them in too
            _depthFirst($_, $topics);
         }
      }
   }
   my @topics;
   push @topics, $topic;
   _depthFirst($topic, \@topics);

   # We shift headers here so every topic gets its own <h1>$topic</h1>
   $prefs{'shift'} += 1 if (scalar @topics > 1);

   my @contentFiles;
   for $topic (@topics) {
      #print STDERR "preparing $topic\n"; # DEBUG
      # Get ready to display HTML topic
      my $htmlData = _getRenderedView($webName, $topic);


      # Fix topic text (i.e. correct any problems with the HTML that htmldoc might not like
      $htmlData = _fixHtml($htmlData, $topic, $webName, \@topics);

      # The data returned also incluides the header. Remove it.
      $htmlData =~ s|.*(<!DOCTYPE)|$1|s;

      # Save this to a temp file for htmldoc processing
      my ($cfh, $contentFile) = tempfile('GenPDFAddOnXXXXXXXXXX',
                                          DIR => File::Spec->tmpdir(),
                                          #UNLINK => 0, # DEBUG
                                          SUFFIX => '.html');
      open $cfh, ">$contentFile";
      print $cfh $hfData . $htmlData;
      close $cfh;
      push @contentFiles, $contentFile;
   }

   # Create a file holding the title data
   my $titleFile = _createTitleFile($webName);

   # Create a temp file for output
   my ($ofh, $outputFile) = tempfile('GenPDFAddOnXXXXXXXXXX',
                                      DIR => File::Spec->tmpdir(),
                                      #UNLINK => 0, # DEBUG
	                              SUFFIX => '.pdf');

   # Convert contentFile to PDF using HTMLDOC
   my @htmldocArgs;
   push @htmldocArgs, "--$prefs{'struct'}",
                      "--quiet",
                      "--links",
                      "--linkstyle", "plain",
                      "--outfile", "$outputFile",
                      "--format", "$prefs{'format'}",
                      "--$prefs{'orientation'}",
                      "--size", "$prefs{'size'}",
                      "--browserwidth", "$prefs{'width'}",
                      "--titlefile", "$titleFile";
   if ($prefs{'toclevels'} eq '0' ) {
      push @htmldocArgs, "--no-toc",
                         "--firstpage", "p1";
   }
   else
   {
      push @htmldocArgs, "--numbered" if $prefs{'numbered'};
      push @htmldocArgs, "--toclevels", "$prefs{'toclevels'}",
                         "--tocheader", "$prefs{'tocheader'}",
                         "--tocfooter", "$prefs{'tocfooter'}",
                         "--firstpage", "toc";
   }
   push @htmldocArgs, "--duplex" if $prefs{'duplex'};
   push @htmldocArgs, "--bodyimage", "$prefs{'bodyimage'}" if $prefs{'bodyimage'};
   push @htmldocArgs, "--logoimage", "$prefs{'logoimage'}" if $prefs{'logoimage'};
   push @htmldocArgs, "--headfootfont", "$prefs{'headfootfont'}" if $prefs{'headfootfont'};
   push @htmldocArgs, "--headfootsize", "$prefs{'headfootsize'}" if $prefs{'headfootsize'};
   push @htmldocArgs, "--header", "$prefs{'header'}" if $prefs{'header'};
   push @htmldocArgs, "--footer", "$prefs{'footer'}" if $prefs{'footer'};
   push @htmldocArgs, "--permissions", "$prefs{'permissions'}" if $prefs{'permissions'};
   push @htmldocArgs, "--bodycolor", "$prefs{'bodycolor'}" if $prefs{'bodycolor'};
   push @htmldocArgs, "--top", "$prefs{'top'}" if $prefs{'top'};
   push @htmldocArgs, "--bottom", "$prefs{'bottom'}" if $prefs{'bottom'};
   push @htmldocArgs, "--left", "$prefs{'left'}" if $prefs{'left'};
   push @htmldocArgs, "--right", "$prefs{'right'}" if $prefs{'right'};

   push @htmldocArgs, @contentFiles;

   #print STDERR "Calling htmldoc with args: @htmldocArgs\n";

   #try the 4.2 sandbox
   my $sandbox = $TWiki::sandbox;
   if (!defined($sandbox)) {  #must be 4.1 or before.
      $sandbox = $TWiki::Plugins::SESSION->{sandbox};
   }

   # Disable CGI feature of newer versions of htmldoc
   # (thanks to Brent Roberts for this fix)
   $ENV{HTMLDOC_NOCGI} = "yes";
   my ( $Output, $exit ) =
     $sandbox->sysCommand(
         $htmldocCmd.' '.join(' ', @htmldocArgs) );
   if( ! -e $outputFile ) {
      die "error running htmldoc ($htmldocCmd): $Output\n";
   }

   #  output the HTML header and the output of HTMLDOC
   my $cd = "filename=${webName}_$topic.";
   try {
       if ($prefs{'format'} =~ /pdf/) {
           print CGI::header( -TYPE => 'application/pdf',
                              -Content_Disposition => $cd.'pdf');
       }
       elsif ($prefs{'format'} =~ /ps/) {
           print CGI::header( -TYPE => 'application/postscript',
                              -Content_Disposition => $cd.'ps');
       }
       else {
           print CGI::header( -TYPE => 'text/html',
                              -Content_Disposition => $cd.'html' );
       }
   } catch Error::Simple with {
   };

   open $ofh, $outputFile;
   while(<$ofh>){
	  print;
   }
   close $ofh;

   # Cleaning up temporary files
   unlink $outputFile, $titleFile;
   unlink @contentFiles; 
}

1;
# vim:et:sw=3:ts=3:tw=0
