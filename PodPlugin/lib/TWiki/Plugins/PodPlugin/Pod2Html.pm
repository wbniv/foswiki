#This based on CPAN Pod::Html module version 1.0503
package TWiki::Plugins::PodPlugin::Pod2Html;
use strict;
use locale;	# make \w work right in non-ASCII lands
use Carp;
use File::Spec::Unix;

use vars qw( @EXPORT $Ignore );

use Exporter qw(import);
@EXPORT = qw(pod2html);

BEGIN {
   $SIG{'__WARN__'} = sub {
      TWiki::Func::writeDebug($_[0]);
   }
}

my @Begin_Stack;
my $Doindex;
my $Backlink;
my ($Listlevel, @Listend);
my (%Items_Named, @Items_Seen);
my $Title;
my $Top;
my $Paragraph;
my %Sections;
my %Local_Items;
my $Is83;
my $PTQuote;
my $HTML;
my $Namespace_Sep; # Namespace separator to use use in wikinames links
                   # ex.: MIME::Base64 is converted to MIME__Base64
my $debug;

init_globals();

sub init_globals {
   @Begin_Stack = (); # begin/end stack
   $debug = $TWiki::Plugins::PodPlugin::debug;
   $Doindex = $TWiki::Plugins::PodPlugin::do_index; # non-zero if we should generate an index
   $Backlink = 'voltar para o topo';		# text for "back to top" links
   $Listlevel = 0;    # current list depth
   @Listend = ();     # the text to use to end the list.
   $Ignore = 1;       # whether or not to format text.  we don't
                      # format text until we hit our first pod
                      # directive.
   @Items_Seen = ();	 # for multiples of the same item in perlfunc
   %Items_Named = ();
   $Title = '';       # title to give the pod(s)
   $Top = 1;          # true if we are at the top of the doc.  used
                      # to prevent the first <hr /> directive.
   $Paragraph = '';   # which paragraph we're processing (used
                      # for error messages)
   $PTQuote = 0;      # status of double-quote conversion
   %Sections = ();    # sections within this page
   %Local_Items = ();
   $Is83 = $^O eq 'dos'; # Is it an 8.3 filesystem?
   $Namespace_Sep = '__';
}

#
# clean_data: global clean-up of pod data
#
sub clean_data($){
   my( $dataref ) = @_;
   for my $i ( 0..$#{$dataref} ) {
      ${$dataref}[$i] =~ s/\s+\Z//;
      # have a look for all-space lines
      if( ${$dataref}[$i] =~ /^\s+$/m and $dataref->[$i] !~ /^\s/ ) {
         my @chunks = split( /^\s+$/m, ${$dataref}[$i] );
         splice( @$dataref, $i, 1, @chunks );
      }
   }
}

sub pod2html {
   local(@ARGV) = @_;
   local($/);
   local $_;
   my $stringPod = shift;

   init_globals();

   $Is83 = 0 if (defined (&Dos::UseLFN) && Dos::UseLFN());

   # escape the backlink argument (same goes for title but is done later...)
   $Backlink = html_escape($Backlink) if defined $Backlink;

   # read the pod a paragraph at a time
   $/ = "";
   my @poddata  = split /\n/, $stringPod;

   # be eol agnostic
   for (@poddata) {
      if (/\r/) {
         if (/\r\n/) {
            @poddata = map {
               s/\r\n/\n/g;
               /\n\n/ ?  map {
                  "$_\n\n"
               } split /\n\n/ : $_
            } @poddata;
         }
         else {
            @poddata = map {
               s/\r/\n/g;
               /\n\n/ ?  map {
                  "$_\n\n"
               } split /\n\n/ : $_
            } @poddata;
         }
         last;
      }
   }

   clean_data( \@poddata );

   # scan the pod for =head[1-6] directives and build an index
   my $index = scan_headings(\%Sections, @poddata);

   # put a title in the HTML file if one wasn't specified
   if ($Title eq '') {
      TITLE_SEARCH: {
         for (my $i = 0; $i < @poddata; $i++) {
            if ($poddata[$i] =~ /^=head1\s*NAME\b/m) {
               for my $para ( @poddata[$i, $i+1] ) {
                  last TITLE_SEARCH
                  if ($Title) = $para =~ /(\S+\s+-+.*\S)/s;
               }
            }

         }
      }
   }
   if (!$Title) {
      # probably a split pod so take first =head[12] as title
      for (my $i = 0; $i < @poddata; $i++) {
         last if ($Title) = $poddata[$i] =~ /^=head[12]\s*(.*)/;
      }
      warn "adopted '$Title' as title\n" if $debug and $Title;
   }
   if ($Title) {
      $Title =~ s/\s*\(.*\)//;
   }
   else {
      warn "$0: no title." if $debug;
      $Title = 'No Title';
   }
   $Title = html_escape($Title);

   # scan the pod for =item directives
   scan_items( \%Local_Items, "", @poddata);

   # put an index at the top of the file.  note, if $Doindex is 0 we
   # still generate an index, but surround it with an html comment.
   # that way some other program can extract it if desired.
   $index =~ s/--+/-/g;
   $HTML .= "<p><a name=\"__index__\"></a></p>\n";
   $HTML .= "<!-- INDEX BEGIN -->\n";
   $HTML .= "<!--\n" unless $Doindex;
   $HTML .= $index;
   $HTML .= "-->\n" unless $Doindex;
   $HTML .= "<!-- INDEX END -->\n\n";
   $HTML .= "<hr />\n" if $Doindex and $index;

   # now convert this file
   my $after_item;             # set to true after an =item
   my $need_dd = 0;
   warn "Converting input file" if $debug;
   foreach my $i (0..$#poddata) {
      $PTQuote = 0; # status of quote conversion

      $_ = $poddata[$i];
      $Paragraph = $i+1;
      if (/^(=.*)/s) {	# is it a pod directive?
         $Ignore = 0;
         $after_item = 0;
         $need_dd = 0;
         $_ = $1;
         if (/^=begin\s+(\S+)\s*(.*)/si) {# =begin
            process_begin($1, $2);
         }
         elsif (/^=end\s+(\S+)\s*(.*)/si) {# =end
            process_end($1, $2);
         }
         elsif (/^=cut/) {			# =cut
            process_cut();
         }
         elsif (/^=pod/) {			# =pod
            process_pod();
         }
         else {
            next if @Begin_Stack && $Begin_Stack[-1] ne 'html';

            if (/^=(head[1-6])\s+(.*\S)/s) {	# =head[1-6] heading
               process_head( $1, $2, $Doindex && $index );
            }
            elsif (/^=item\s*(.*\S)?/sm) {	# =item text
               $need_dd = process_item( $1 );
               $after_item = 1;
            }
            elsif (/^=over\s*(.*)/) {		# =over N
               process_over();
            }
            elsif (/^=back/) {		# =back
               process_back();
            }
            elsif (/^=for\s+(\S+)\s*(.*)/si) {# =for
               process_for($1,$2);
            }
            else {
               /^=(\S*)\s*/;
               warn "$0: unknown pod directive '$1' in " . "paragraph $Paragraph. ignoring." if $debug;
            }
         }
         $Top = 0;
      }
      else {
         next if $Ignore;
         next if @Begin_Stack && $Begin_Stack[-1] ne 'html';
         $HTML .= "<dd>\n" if $need_dd;
         my $text = $_;
         if( $text =~ /\A\s+/ ) {
            process_pre( \$text );
            $HTML .= "<pre>\n$text</pre>\n";
         }
         else {
            process_text( \$text );

            # experimental: check for a paragraph where all lines
            # have some ...\t...\t...\n pattern
            if( $text =~ /\t/ ) {
               my @lines = split( "\n", $text );
               if( @lines > 1 ) {
                  my $all = 2;
                  foreach my $line ( @lines ) {
                     if( $line =~ /\S/ && $line !~ /\t/ ) {
                        $all--;
                        last if $all == 0;
                     }
                  }
                  if( $all > 0 ) {
                     $text =~ s/\t+/<td>/g;
                     $text =~ s/^/<tr><td>/gm;
                     $text = '<table cellspacing="0" cellpadding="0">' . $text . '</table>';
                  }
               }
            }
            ## end of experimental

            if($text) {
               $HTML .= "$text\n";
            }
         }
         $HTML .= "</dd>\n" if $need_dd;
         $after_item = 0;
      }
   }

   # finish off any pending directives
   finish_list();

   # link to page index
   $HTML .= "<p><a href=\"#__index__\"><small>$Backlink</small></a></p>\n" if $Doindex and $index and $Backlink;

   warn "Finished\n" if $debug;
   return $HTML;
}

#
# scan_headings - scan a pod file for head[1-6] tags, note the tags, and
#  build an index.
#
sub scan_headings {
   my($sections, @data) = @_;
   my($tag, $which_head, $otitle, $listdepth, $index);

   local $Ignore = 0;

   $listdepth = 0;
   $index = "";

   # scan for =head directives, note their name, and build an index
   #  pointing to each of them.
   foreach my $line (@data) {
      if ($line =~ /^=(head)([1-6])\s+(.*)/) {
         ($tag, $which_head, $otitle) = ($1,$2,$3);

         my $title = depod( $otitle );
         my $name = anchorify( $title );
         $$sections{$name} = 1;
         $title = process_text( \$otitle );

         while ($which_head != $listdepth) {
            if ($which_head > $listdepth) {
               $index .= "\n" . ("\t" x $listdepth) . "<ul>\n";
               $listdepth++;
            }
            elsif ($which_head < $listdepth) {
               $listdepth--;
               $index .= "\n" . ("\t" x $listdepth) . "</ul>\n";
            }
         }
         $index .= "\n" . ("\t" x $listdepth) . "<li><a href=\"#$name\">$title</a></li>";
      }
   }

   # finish off the lists
   while ($listdepth--) {
      $index .= "\n" . ("\t" x $listdepth) . "</ul>\n";
   }

   # get rid of bogus lists
   $index =~ s,\t*<ul>\s*</ul>\n,,g;

   # remove quebras de linha duplicadas
   $index =~ s/\n+/\n/igo;

   return $index;
}

#
# scan_items - scans the pod specified by $pod for =item directives.  we
#  will use this information later on in resolving C<> links.
#
sub scan_items {
   my( $itemref, $pod, @poddata ) = @_;
   my($i, $item);
   local $_;

   $pod =~ s/\.pod\z//;

   foreach $i (0..$#poddata) {
      my $txt = depod( $poddata[$i] );

      # figure out what kind of item it is.
      # Build string for referencing this item.
      if ( $txt =~ /\A=item\s+\*\s*(.*)\Z/s ) { # bullet
         next unless $1;
         $item = $1;
      }
      elsif( $txt =~ /\A=item\s+(?>\d+\.?)\s*(.*)\Z/s ) { # numbered list
         $item = $1;
      }
      elsif( $txt =~ /\A=item\s+(.*)\Z/s ) { # plain item
         $item = $1;
      }
      else {
         next;
      }
      my $fid = fragment_id( $item );
      $$itemref{$fid} = "$pod" if $fid;
   }
}

#
# process_head - convert a pod head[1-6] tag and convert it to HTML format.
#
sub process_head {
   my($tag, $heading, $hasindex) = @_;

   # figure out the level of the =head
   my ($level) = $tag =~ /head([1-6])/;

   if( $Listlevel ){
      warn "$0: unterminated list at =head in paragraph $Paragraph.  ignoring." if $debug;
      while( $Listlevel ) {
         process_back();
      }
   }

   if( $level == 1 && ! $Top ){
      $HTML .= "<p>\n";
      $HTML .= "<a href=\"#__index__\"><small>$Backlink</small></a>\n" if $hasindex and $Backlink;
      $HTML .= "</p>\n<hr />\n"
   } 

   my $name = anchorify( depod( $heading ) );
   my $convert = process_text( \$heading );
   $HTML .= "<h$level><a name=\"$name\">$convert</a></h$level>\n";
}

#
# emit_item_tag - print an =item's text
# Note: The global $EmittedItem is used for inhibiting self-references.
#
my $EmittedItem;

sub emit_item_tag($$$){
   my( $otext, $text, $compact ) = @_;
   my $item = fragment_id( $text );

   $EmittedItem = $item;

   $HTML .= '<strong>';
   if ($Items_Named{$item}++) {
      $HTML .= process_text( \$otext );
   }
   else {
      my $name = 'item_' . $item;
      $name = anchorify($name);
      $HTML .= qq{<a name="$name">} . process_text( \$otext ) . '</a>';
   }
   $HTML .= "</strong><br />\n";
   undef( $EmittedItem );
}

sub emit_li {
   my( $tag ) = @_;
   if( $Items_Seen[$Listlevel]++ == 0 ){
      push( @Listend, "</$tag>" );
      $HTML .= "<$tag>\n";
   }
   my $emitted = $tag eq 'dl' ? 'dt' : 'li';
   $HTML .= "\n<$emitted>";
   return $emitted;
}

#
# process_item - convert a pod item tag and convert it to HTML format.
#
sub process_item {
   my( $otext ) = @_;
   my $need_dd = 0; # set to 1 if we need a <dd></dd> after an item

   # lots of documents start a list without doing an =over.  this is
   # bad!  but, the proper thing to do seems to be to just assume
   # they did do an =over.  so warn them once and then continue.
   if( $Listlevel == 0 ){
      warn "$0: unexpected =item directive in paragraph $Paragraph.  ignoring." if $debug;
      process_over();
   }

   # remove formatting instructions from the text
   my $text = depod( $otext );

   my $emitted; # the tag actually emitted, used for closing

   # all the list variants:
   if( $text =~ /\A\*/ ){ # bullet
      $emitted = emit_li( 'ul' );
      if ($text =~ /\A\*\s+(.+)\Z/s ) { # with additional text
         my $tag = $1;
         $otext =~ s/\A\*\s+//;
         emit_item_tag( $otext, $tag, 1 );
      }

   }
   elsif( $text =~ /\A\d+/ ){ # numbered list
      $emitted = emit_li( 'ol' );
      if ($text =~ /\A(?>\d+\.?)\s*(.+)\Z/s ) { # with additional text
         my $tag = $1;
         $otext =~ s/\A\d+\.?\s*//;
         emit_item_tag( $otext, $tag, 1 );
      }
   }
   else {			# definition list
      $emitted = emit_li( 'dl' );
      if ($text =~ /\A(.+)\Z/s ){ # should have text
         emit_item_tag( $otext, $text, 1 );
      }
      $need_dd = 1;
   }
   $HTML .= "</$emitted>" if $emitted;
   $HTML .= "\n";
   return $need_dd;
}

#
# process_over - process a pod over tag and start a corresponding HTML list.
#
sub process_over {
   # start a new list
   $Listlevel++;
   push( @Items_Seen, 0 );
}

#
# process_back - process a pod back tag and convert it to HTML format.
#
sub process_back {
   if( $Listlevel == 0 ){
      warn "$0: unexpected =back directive in paragraph $Paragraph.  ignoring." if $debug;
      return;
   }

   # close off the list.  note, I check to see if $Listend[$Listlevel] is
   # defined because an =item directive may have never appeared and thus
   # $Listend[$Listlevel] may have never been initialized.
   $Listlevel--;
   if( defined $Listend[$Listlevel] ){
      $HTML .= $Listend[$Listlevel];
      $HTML .= "\n";
      pop( @Listend );
   }

   # clean up item count
   pop( @Items_Seen );
}

#
# process_cut - process a pod cut tag, thus start ignoring pod directives.
#
sub process_cut {
   $Ignore = 1;
}

#
# process_pod - process a pod tag, thus stop ignoring pod directives
# until we see a corresponding cut.
#
sub process_pod {
   # no need to set $Ignore to 0 cause the main loop did it
}

#
# process_for - process a =for pod tag.  if it's for html, spit
# it out verbatim, if illustration, center it, otherwise ignore it.
#
sub process_for {
   my($whom, $text) = @_;
   if ( $whom =~ /^(pod2)?html$/i) {
      $HTML .= $text;
   }
   elsif ($whom =~ /^illustration$/i) {
      1 while chomp $text;
      for my $ext (qw[.png .gif .jpeg .jpg .tga .pcl .bmp]) {
         $text .= $ext, last if -r "$text$ext";
      }
      $HTML .= qq{<p align="center"><img src="$text" alt="$text illustration" /></p>};
   }
}

#
# process_begin - process a =begin pod tag.  this pushes
# whom we're beginning on the begin stack.  if there's a
# begin stack, we only print if it us.
#
sub process_begin {
   my($whom, $text) = @_;
   $whom = lc($whom);
   push (@Begin_Stack, $whom);
   if ( $whom =~ /^(pod2)?html$/) {
      $HTML .= $text if $text;
   }
}

#
# process_end - process a =end pod tag.  pop the
# begin stack.  die if we're mismatched.
#
sub process_end {
   my($whom, $text) = @_;
   $whom = lc($whom);
   if ($Begin_Stack[-1] ne $whom ) {
      die "Unmatched begin/end at chunk $Paragraph\n"
   }
   pop( @Begin_Stack );
}

#
# process_pre - indented paragraph, made into <pre></pre>
#
sub process_pre {
   my( $text ) = @_;
   my( $rest );
   return if $Ignore;

   $rest = $$text;

   # insert spaces in place of tabs
   $rest =~ s#(.+)#
   my $line = $1;
   1 while $line =~ s/(\t+)/' ' x ((length($1) * 8) - $-[0] % 8)/e;
   $line;
   #eg;

   # convert some special chars to HTML escapes
   $rest = html_escape($rest);

   # try and create links for all occurrences of perl.* within
   # the preformatted text.
   $rest =~ s{(\s*)(perl\w+)}{
         "$1$2";
   }xeg;

   $rest =~ s{(<a\ href="?) ([^>:]*:)? ([^>:]*) \.pod: ([^>:]*:)?}{
      my $url = "$1$3";
      "$url";
   }xeg;

   # Look for embedded URLs and make them into links.  We don't
   # relativize them since they are best left as the author intended.

   my $urls = '(' . join ('|', qw{ http telnet mailto news gopher file wais ftp } ) . ')';

   my $ltrs = '\w';
   my $gunk = '/#~:.?+=&%@!\-';
   my $punc = '.:!?\-;';
   my $any  = "${ltrs}${gunk}${punc}";

   $rest =~ s{
       \b             # start at word boundary
       (              # begin $1  {
       $urls :        # need resource and a colon
       (?!:)          # Ignore File::, among others.
       [$any] +?		 # followed by one or more of any valid
                      #   character, but be conservative and
                      #   take only what you need to....
       )              # end   $1  }
       (?=
          &quot; &gt; # maybe pre-quoted '<a href="...">'
          |           # or:
          [$punc]*    # 0 or more punctuation
          (?:         #   followed
             [^$any]  #   by a non-url char
             |        #   or
             $        #   end of the string
          )           #
          |           # or else
          $           #   then end of the string
       )
   }{<a href="$1">$1</a>}igox;

   # text should be as it is (verbatim)
   $$text = $rest;
}

# pure text processing
#
# pure_text/inIS_text: differ with respect to automatic C<> recognition.
# we don't want this to happen within IS
#
sub pure_text($){
   my $text = shift();
   process_puretext( $text, \$PTQuote, 1 );
}

sub inIS_text($){
   my $text = shift();
   process_puretext( $text, \$PTQuote, 0 );
}

#
# process_puretext - process pure text (without pod-escapes) converting
#  double-quotes and handling implicit C<> links.
#
sub process_puretext {
   my($text, $quote, $notinIS) = @_;

   ## Guessing at func() or [$@%&]*var references in plain text is destined
   ## to produce some strange looking ref's. uncomment to disable:
   ## $notinIS = 0;

   my(@words, $lead, $trail);

   # convert double-quotes to single-quotes
   if( $$quote && $text =~ s/"/''/s ) {
      $$quote = 0;
   }
   while ($text =~ s/"([^"]*)"/``$1''/sg) {};
   $$quote = 1 if $text =~ s/"/``/s;

   # keep track of leading and trailing white-space
   $lead  = ($text =~ s/\A(\s+)//s ? $1 : "");
   $trail = ($text =~ s/(\s+)\Z//s ? $1 : "");

   # split at space/non-space boundaries
   @words = split( /(?<=\s)(?=\S)|(?<=\S)(?=\s)/, $text );

   # process each word individually
   foreach my $word (@words) {
      # skip space runs
      next if $word =~ /^\s*$/;
      # see if we can infer a link
      if( $notinIS && $word =~ /^(\w+)\((.*)\)$/ ) {
         # has parenthesis so should have been a C<> ref
         ## try for a pagename (perlXXX(1))?
         my( $func, $args ) = ( $1, $2 );
         if( $args =~ /^\d+$/ ){
            my $url = page_sect( $word, '' );
            if( defined $url ) {
               $word = "<a href=\"$url\">the $word manpage</a>";
               next;
            }
         }
         ## try function name for a link, append tt'ed argument list
         $word = emit_C( $func, '', "($args)");

         #### disabled. either all (including $\W, $\w+{.*} etc.) or nothing.
         ##      } elsif( $notinIS && $word =~ /^[\$\@%&*]+\w+$/) {
         ##	    # perl variables, should be a C<> ref
         ##	    $word = emit_C( $word );
      }
      elsif ($word =~ m,^\w+://\w,) {
         # looks like a URL
         # Don't relativize it: leave it as the author intended
         $word = qq(<a href="$word">$word</a>);
      }
      elsif ($word =~ /[\w.-]+\@[\w-]+\.\w/) {
         # looks like an e-mail address
         my ($w1, $w2, $w3) = ("", $word, "");
         ($w1, $w2, $w3) = ("(", $1, ")$2") if $word =~ /^\((.*?)\)(,?)/;
         ($w1, $w2, $w3) = ("&lt;", $1, "&gt;$2") if $word =~ /^<(.*?)>(,?)/;
         $word = qq($w1<a href="mailto:$w2">$w2</a>$w3);
      }
      else {
         $word = html_escape($word) if $word =~ /["&<>]/;
      }
   }

   # put everything back together
   return $lead . join( '', @words ) . $trail;
}

#
# process_text - handles plaintext that appears in the input pod file.
# there may be pod commands embedded within the text so those must be
# converted to html commands.
#

sub process_text1($$;$$);
sub pattern ($) {
   $_[0] ? '[^\S\n]+'.('>' x ($_[0] + 1)) : '>'
}

sub closing ($) {
   local($_) = shift;
   (defined && s/\s+$//) ? length : 0;
}

sub process_text {
   return if $Ignore;
   my( $tref ) = @_;
   my $res = process_text1( 0, $tref );
   $$tref = $res;
}

sub process_text1($$;$$){
   my( $lev, $rstr, $func, $closing ) = @_;
   my $res = '';

   unless (defined $func) {
      $func = '';
      $lev++;
   }

   if( $func eq 'B' ) {
      # B<text> - boldface
      $res = '<strong>' . process_text1( $lev, $rstr ) . '</strong>';
   }
   elsif( $func eq 'C' ) {
      # C<code> - can be a ref or <code></code>
      # need to extract text
      my $par = go_ahead( $rstr, 'C', $closing );

      ## clean-up of the link target
      my $text = depod( $par );

      ### my $x = $par =~ /[BI]</ ? 'yes' : 'no' ;
      ### print STDERR "-->call emit_C($par) lev=$lev, par with BI=$x\n";
      $res = emit_C( $text, $lev > 1 || ($par =~ /[BI]</) );
   }
   elsif( $func eq 'E' ) {
      # E<x> - convert to character
      $$rstr =~ s/^([^>]*)>//;
      my $escape = $1;
      $escape =~ s/^(\d+|X[\dA-F]+)$/#$1/i;
      $res = "&$escape;";

   }
   elsif( $func eq 'F' ) {
      # F<filename> - italizice
      $res = '<em>' . process_text1( $lev, $rstr ) . '</em>';
   }
   elsif( $func eq 'I' ) {
      # I<text> - italizice
      $res = '<em>' . process_text1( $lev, $rstr ) . '</em>';
   }
   elsif( $func eq 'L' ) {
      # L<link> - link
      ## L<text|cross-ref> => produce text, use cross-ref for linking
      ## L<cross-ref> => make text from cross-ref
      ## need to extract text
      my $par = go_ahead( $rstr, 'L', $closing );

      # some L<>'s that shouldn't be:
      # a) full-blown URL's are emitted as-is
      if( $par =~ m{^\w+://}s ) {
         return make_URL_href( $par );
      }
      # b) C<...> is stripped and treated as C<>
      if( $par =~ /^C<(.*)>$/ ){
         my $text = depod( $1 );
         return emit_C( $text, $lev > 1 || ($par =~ /[BI]</) );
      }

      # analyze the contents
      $par =~ s/\n/ /g;   # undo word-wrapped tags
      my $opar = $par;
      my $linktext;
      if( $par =~ s{^([^|]+)\|}{} ){
         $linktext = $1;
      }

      # make sure sections start with a /
      $par =~ s{^"}{/"};

      my( $page, $section, $ident );

      # check for link patterns
      if( $par =~ m{^([^/]+?)/(?!")(.*?)$} ){  # name/ident
         # we've got a name/ident (no quotes)
         ( $page, $ident ) = ( $1, $2 );

      }
      elsif( $par =~ m{^(.*?)/"?(.*?)"?$} ){   # [name]/"section"
         # even though this should be a "section", we go for ident first
         ( $page, $ident ) = ( $1, $2 );

      }
      elsif( $par =~ /\s/ ){                   # this must be a section with missing quotes
         ( $page, $section ) = ( '', $par );

      }
      else {
         ( $page, $section ) = ( $par, '' );
      }

      # now, either $section or $ident is defined. the convoluted logic
      # below tries to resolve L<> according to what the user specified.
      # failing this, we try to find the next best thing...
      my( $url, $ltext, $fid );

      RESOLVE: {
         if( defined $ident ) {
            ## try to resolve $ident as an item
            ( $url, $fid ) = coderef( $page, $ident );
            if( $url ) {
               if( ! defined( $linktext ) ) {
                  $linktext = $ident;
                  $linktext .= " in " if $ident && $page;
                  $linktext .= "the $page manpage" if $page;
               }
               last RESOLVE;
            }
            ## no luck: go for a section (auto-quoting!)
            $section = $ident;
         }
         ## now go for a section
         my $htmlsection = htmlify( $section );
         $url = page_sect( $page, $htmlsection );
         if( $url ) {
            if( ! defined( $linktext ) ) {
               $linktext = $section;
               $linktext .= " in " if $section && $page;
               $linktext .= "the $page manpage" if $page;
            }
            last RESOLVE;
         }
         ## no luck: go for an ident
         if( $section ) {
            $ident = $section;
         }
         else {
            $ident = $page;
            $page  = undef();
         }
         ( $url, $fid ) = coderef( $page, $ident );
         if( $url ) {
            if( ! defined( $linktext ) ) {
               $linktext = $ident;
               $linktext .= " in " if $ident && $page;
               $linktext .= "the $page manpage" if $page;
            }
            last RESOLVE;
         }

         # warning; show some text.
         $linktext = $opar unless defined $linktext;
         warn "$0: cannot resolve L<$opar> in paragraph $Paragraph." if $debug;
      }

      # now we have a URL or just plain code
      $$rstr = $linktext . '>' . $$rstr;
      if( defined( $url ) ) {
         $res = "<a href=\"$url\">" . process_text1( $lev, $rstr ) . '</a>';
      }
      else {
         $res = '<em>' . process_text1( $lev, $rstr ) . '</em>';
      }

   }
   elsif( $func eq 'S' ) {
      # S<text> - non-breaking spaces
      $res = process_text1( $lev, $rstr );
      $res =~ s/ /&nbsp;/g;
   }
   elsif( $func eq 'X' ) {
      # X<> - ignore
      $$rstr =~ s/^[^>]*>//;
   }
   elsif( $func eq 'Z' ) {
      # Z<> - empty
      warn "$0: invalid X<> in paragraph $Paragraph.\n"
      unless $$rstr =~ s/^>// or $debug;
   }
   else {
      my $term = pattern $closing;
      while( $$rstr =~ s/\A(.*?)(([BCEFILSXZ])<(<+[^\S\n]+)?|$term)//s ) {
         # all others: either recurse into new function or
         # terminate at closing angle bracket(s)
         my $pt = $1;
         $pt .= $2 if !$3 &&  $lev == 1;
         $res .= $lev == 1 ? pure_text( $pt ) : inIS_text( $pt );
         return $res if !$3 && $lev > 1;
         if( $3 ){
            $res .= process_text1( $lev, $rstr, $3, closing $4 );
         }
      }
      if( $lev == 1 ){
         $res .= pure_text( $$rstr );
      } else {
         warn "$0: undelimited $func<> in paragraph $Paragraph." if $debug;
      }
   }
   return $res;
}

#
# go_ahead: extract text of an IS (can be nested)
#
sub go_ahead($$$){
   my( $rstr, $func, $closing ) = @_;
   my $res = '';
   my @closing = ($closing);
   while( $$rstr =~ s/\A(.*?)(([BCEFILSXZ])<(<+[^\S\n]+)?|@{[pattern $closing[0]]})//s ) {
      $res .= $1;
      unless( $3 ) {
         shift @closing;
         return $res unless @closing;
      }
      else {
         unshift @closing, closing $4;
      }
      $res .= $2;
   }
   warn "$0: undelimited $func<> in paragraph $Paragraph." if $debug;
   return $res;
}

#
# emit_C - output result of C<text>
#    $text is the depod-ed text
#
sub emit_C($;$$){
   my( $text, $nocode, $args ) = @_;
   $args = '' unless defined $args;
   my $res;
   my( $url, $fid ) = coderef( undef(), $text );

   # need HTML-safe text
   my $linktext = html_escape( "$text$args" );

   if( defined( $url ) && (!defined( $EmittedItem ) || $EmittedItem ne $fid ) ) {
      $res = "<a href=\"$url\"><code>$linktext</code></a>";
   }
   elsif( 0 && $nocode ) {
      $res = $linktext;
   }
   else {
      $res = "<code>$linktext</code>";
   }
   return $res;
}

#
# html_escape: make text safe for HTML
#
sub html_escape {
   my $rest = $_[0];
   $rest =~ s/&/&amp;/g;
   $rest =~ s/</&lt;/g;
   $rest =~ s/>/&gt;/g;
   $rest =~ s/"/&quot;/g;
   # &apos; is only in XHTML, not HTML4.  Be conservative
   $rest =~ s/'/&apos;/g;
   return $rest;
}

#
# dosify - convert filenames to 8.3
#
sub dosify {
   my($str) = @_;
   return lc($str) if $^O eq 'VMS';     # VMS just needs casing
   if ($Is83) {
      $str = lc $str;
      $str =~ s/(\.\w+)/substr ($1,0,4)/ge;
      $str =~ s/(\w+)/substr ($1,0,8)/ge;
   }
   return $str;
}

#
# page_sect - make a URL from the text of a L<>
#
sub page_sect($$) {
   my( $page, $section ) = @_;
   my( $linktext, $page83, $link ); # work strings

   # check if we know that this is a section in this page
   if (defined $Sections{$page}) {
      $section = $page;
      $page = "";
   }

   $page83 = dosify($page);
   if ($page eq "") {
      $link = "#" . anchorify( $section );
   }
   elsif ( $page =~ /::/ ) {
      $page =~ s,::,$Namespace_Sep,g;
      # Search page cache for an entry keyed under the html page name,
      # then look to see what directory that page might be in.  NOTE:
      # this will only find one page. A better solution might be to produce
      # an intermediate page that is an index to all such pages.
      my $page_name = $page ;
      $page_name =~ s,^.*/,,s ;
      $link = "$page";
      $link .= "#" . anchorify( $section ) if $section;
   }
   else {
      $section = anchorify( $section ) if $section ne "";


      # if there is a directory by the name of the page, then assume that an
      # appropriate section will exist in the subdirectory
      if ($section ne "") {
         $link = "$1#$section";

         # since there is no directory by the name of the page, the section will
         # have to exist within a .html of the same name.  thus, make sure there
         # is a .pod or .pm that might become that .html
      } else {
         $section = "#$section" if $section;
         # check if there is a .pod with the page name
         $link = $page;
      }
   }

   return $link ? ucfirst $link : undef;
}

#
# relativize_url - convert an absolute URL to one relative to a base URL.
# Assumes both end in a filename.
#
sub relativize_url {
   my ($dest, $source) = @_;

   my ($dest_volume, $dest_directory, $dest_file) = File::Spec::Unix->splitpath( $dest );
   $dest = File::Spec::Unix->catpath( $dest_volume, $dest_directory, '' );

   my ($source_volume,$source_directory,$source_file) = File::Spec::Unix->splitpath( $source );
   $source = File::Spec::Unix->catpath( $source_volume, $source_directory, '' );

   my $rel_path = '' ;
   if ( $dest ne '' ) {
      $rel_path = File::Spec::Unix->abs2rel( $dest, $source );
   }

   if ( $rel_path ne '' && substr( $rel_path, -1 ) ne '/' && substr( $dest_file, 0, 1 ) ne '#' ) {
      $rel_path .= "/$dest_file" ;
   }
   else {
      $rel_path .= "$dest_file" ;
   }

   return $rel_path ;
}

#
# coderef - make URL from the text of a C<>
#
sub coderef($$){
   my( $page, $item ) = @_;
   my( $url );

   my $fid = fragment_id( $item );
   if( defined( $page ) ) {
      # we have been given a $page...
      $page =~ s{::}{/}g;

      # Do we take it? Item could be a section!
      my $base = "";
      $base =~ s{[^/]*/}{};
      #if( $base ne "$page.html" ){
      if( $base ne "$page" ) {
         $page = undef();
      }
   }
   else {
      if( defined( $fid ) ) {
         if( exists $Local_Items{$fid} ) {
            $page = $Local_Items{$fid};
         }
      }
   }

   # if there was a pod file that we found earlier with an appropriate
   # =item directive, then create a link to that page.
   if( defined $page ) {
      if( $page ) {
         my $link = "$page#item_" . anchorify($fid);

         $url = $link;
      }
      else {
         $url = "#item_" . anchorify($fid);
      }

      confess "url has space: $url" if $url =~ /"[^"]*\s[^"]*"/;
   }
   return( $url, $fid );
}

#
# Adapted from Nick Ing-Simmons' PodToHtml package.
sub relative_url {
   my $source_file = shift ;
   my $destination_file = shift;

   my $source = URI::file->new_abs($source_file);
   my $uo = URI::file->new($destination_file,$source)->abs;
   return $uo->rel->as_string;
}

#
# finish_list - finish off any pending HTML lists.  this should be called
# after the entire pod file has been read and converted.
#
sub finish_list {
   while ($Listlevel > 0) {
      $HTML .= "</dl>\n";
      $Listlevel--;
   }
}

#
# htmlify - converts a pod section specification to a suitable section
# specification for HTML. Note that we keep spaces and special characters
# except ", ? (Netscape problem) and the hyphen (writer's problem...).
#
sub htmlify {
   my( $heading) = @_;
   $heading =~ s/(\s+)/ /g;
   $heading =~ s/\s+\Z//;
   $heading =~ s/\A\s+//;
   # The hyphen is a disgrace to the English language.
   $heading =~ s/[-"?]//g;
   $heading = lc( $heading );
   return $heading;
}

#
# similar to htmlify, but turns non-alphanumerics into underscores
#
sub anchorify {
   my ($anchor) = @_;
   $anchor = htmlify($anchor);
   $anchor =~ s/\W/_/g;
   return $anchor;
}

#
# depod - convert text by eliminating all interior sequences
# Note: can be called with copy or modify semantics
#
my %E2c;
$E2c{lt}     = '<';
$E2c{gt}     = '>';
$E2c{sol}    = '/';
$E2c{verbar} = '|';
$E2c{amp}    = '&'; # in Tk's pods

sub depod1($;$$);

sub depod($){
   my $string;
   if( ref( $_[0] ) ) {
      $string =  ${$_[0]};
      ${$_[0]} = depod1( \$string );
   }
   else {
      $string =  $_[0];
      depod1( \$string );
   }
}

sub depod1($;$$){
   my( $rstr, $func, $closing ) = @_;
   my $res = '';
   return $res unless defined $$rstr;
   if( ! defined( $func ) ) {
      # skip to next begin of an interior sequence
      while( $$rstr =~ s/\A(.*?)([BCEFILSXZ])<(<+[^\S\n]+)?// ) {
         # recurse into its text
         $res .= $1 . depod1( $rstr, $2, closing $3);
      }
      $res .= $$rstr;
   }
   elsif( $func eq 'E' ) {
      # E<x> - convert to character
      $$rstr =~ s/^([^>]*)>//;
      $res .= $E2c{$1} || "";
   }
   elsif( $func eq 'X' ) {
      # X<> - ignore
      $$rstr =~ s/^[^>]*>//;
   }
   elsif( $func eq 'Z' ) {
      # Z<> - empty
      $$rstr =~ s/^>//;
   }
   else {
      # all others: either recurse into new function or
      # terminate at closing angle bracket
      my $term = pattern $closing;
      while( $$rstr =~ s/\A(.*?)(([BCEFILSXZ])<(<+[^\S\n]+)?|$term)// ){
         $res .= $1;
         last unless $3;
         $res .= depod1( $rstr, $3, closing $4 );
      }
      ## If we're here and $2 ne '>': undelimited interior sequence.
      ## Ignored, as this is called without proper indication of where we are.
      ## Rely on process_text to produce diagnostics.
   }
   return $res;
}

#
# fragment_id - construct a fragment identifier from:
#   a) =item text
#   b) contents of C<...>
#
my @HC;
sub fragment_id {
   my $text = shift();
   $text =~ s/\s+\Z//s;
   if( $text ){
      # a method or function?
      return $1 if $text =~ /(\w+)\s*\(/;
      return $1 if $text =~ /->\s*(\w+)\s*\(?/;

      # a variable name?
      return $1 if $text =~ /^([$@%*]\S+)/;

      # some pattern matching operator?
      return $1 if $text =~ m|^(\w+/).*/\w*$|;

      # fancy stuff... like "do { }"
      return $1 if $text =~ m|^(\w+)\s*{.*}$|;

      # honour the perlfunc manpage: func [PAR[,[ ]PAR]...]
      # and some funnies with ... Module ...
      return $1 if $text =~ m{^([a-z\d_]+)(\s+[A-Z\d,/& ]+)?$};
      return $1 if $text =~ m{^([a-z\d]+)\s+Module(\s+[A-Z\d,/& ]+)?$};

      # text? normalize!
      $text =~ s/\s+/_/sg;
      $text =~ s{(\W)}{
         defined( $HC[ord($1)] ) ? $HC[ord($1)]
         : ( $HC[ord($1)] = sprintf( "%%%02X", ord($1) ) ) }gxe;
      $text = substr( $text, 0, 50 );
   }
   else {
      return undef();
   }
}

#
# make_URL_href - generate HTML href from URL
# Special treatment for CGI queries.
#
sub make_URL_href($){
   my( $url ) = @_;
   if( $url !~ s{^(http:[-\w/#~:.+=&%@!]+)(\?.*)$}{<a href="$1$2">$1</a>}i ){
      $url = "<a href=\"$url\">$url</a>";
   }
   return $url;
}

1;
