# See bottom of file for license and copyright details
package Foswiki::Plugins::PublishPlugin::Publisher;

use strict;

use Foswiki;
use Foswiki::Func;
use Error ':try';

sub new {
    my ($class, $session) = @_;

    my $this = bless({
        session => $session,
        templatesWanted => 'view',
        # used to prefix alternate template renderings
        templateLocation => '',
        # this records which templates (e.g. view, viewprint, viuehandheld,
        # etc) have been referred to and thus should be generated.
        templatesReferenced => {},
        historyTopic => 'PublishPluginHistory',
        inclusions => '.*',
        exclusions => '',
        topicFilter => '',
        outputformat => 'file',
    }, $class);
    my $query = Foswiki::Func::getCgiQuery();
    if ($query && $query->param('configtopic')) {
        $this->{configtopic} = $query->param('configtopic');
        $query->delete('configtopic');
        $this->_configureFromTopic();
    } elsif ($query) {
        $this->_configureFromQuery($query);
    }
    $this->{publishskin} ||=
      Foswiki::Func::getPreferencesValue('PUBLISHSKIN') || 'basic_publish';
    return $this;
}

sub finish {
    my $this = shift;
    $this->{session} = undef;
}

sub _configureFromTopic {
    my ($this) = @_;

    # Parameters are defined in config topic
    my ($cw, $ct) = Foswiki::Func::normalizeWebTopicName(
        $this->{web}, $this->{configtopic});
    unless( Foswiki::Func::topicExists($cw, $ct) ) {
        die "Specified configuration topic $cw.$ct does not exist!\n";
    }
    my ($cfgm, $cfgt) = Foswiki::Func::readTopic($cw, $ct);
    unless( Foswiki::Func::checkAccessPermission(
        "VIEW", $this->{publisher}, $cfgt, $ct, $cw)) {
        die "Access to $cw.$ct denied";
    }

    $cfgt = Foswiki::Func::expandCommonVariables(
        $cfgt, $this->{configtopic}, $this->{web}, $cfgm);

    # SMELL: common preferences parser?
    foreach my $line (split(/\r?\n/, $cfgt)) {
        next unless $line =~ /^\s+\*\s+Set\s+(?:PUBLISH_)?([A-Z]+)\s*=\s*(.*?)\s*$/;
        my $k = $1;
        my $v = $2;

        if ( $k eq 'HISTORY' && $v ) {
            $this->{historyTopic} = $v;
        } elsif ( $k eq 'INCLUSIONS' ) {
            $v =~ s/([*?])/.$1/g;
            $v =~ s/,/|/g;
            $this->{inclusions} = $v;
        } elsif ( $k eq 'EXCLUSIONS' ) {
            $v =~ s/([*?])/.$1/g;
            $v =~ s/,/|/g;
            $this->{exclusions} = $v;
        } elsif ( $k eq 'TOPICSEARCH' || $k eq 'FILTER' ) {
            $this->{topicFilter} = $v;
        } elsif ( $k eq 'PUBLISHSKIN' || $k eq 'SKIN' ) {
            $this->{publishskin} = $v;
        } elsif( $k eq 'EXTRAS' ) {
            $this->{genopt} = $v;
        } elsif( $k eq 'FORMAT' ) {
            $v =~ /(\w*)/;
            $this->{outputformat} = $1;
        } elsif ($k eq 'DEBUG' ) {
            $this->{debug} = $v;
        } elsif ($k eq 'VERSIONS') {
            $this->{versionstopic} = $v;
        } elsif ($k eq 'TEMPLATES' ) {
            $v =~ /([\w,]*)/;
            $this->{templatesWanted} = $1;
        } elsif ($k eq 'TEMPLATELOCATION' ) {
            if (-d $v) {
                $v =~ /(.*)/;
                $this->{templateLocation} = $1;
            }
        } elsif ($k eq 'INSTANCE' ) {
            $Foswiki::cfg{PublishPlugin}{Dir} .= $v.'/' if $v;
            $Foswiki::cfg{PublishPlugin}{URL} .= $v.'/' if $v;
        }
    }
}

sub _configureFromQuery {
    my ($this, $query) = @_;

    # Parameters are defined in the query
    if ( defined($query->param('history')) ) {
        my $v = $query->param('history');
        if ($v =~ /(\w+)/) {
            $this->{historyTopic} = $1;
        }
        $query->delete('history');
    }
    if ( defined($query->param('inclusions')) ) {
        my $v = $query->param('inclusions');
        $v =~ s/([*?])/.$1/g;
        $v =~ s/,/|/g;
        $this->{inclusions} = $v;
        $query->delete('inclusions');
    }
    if ( defined($query->param('exclusions')) ) {
        my $v = $query->param('exclusions');
        $v =~ s/([*?])/.$1/g;
        $v =~ s/,/|/g;
        $this->{exclusions} = $v;
        $query->delete('exclusions');
    }
    if ( defined($query->param('versions')) ) {
        my $v = $query->param('versions');
        $this->{versionstopic} = $v;
        $query->delete('versions');
    }
    if (defined $query->param('enableplugins')) {
        my $v = $query->param('enableplugins');
        $this->{enableplugins} = $v;
        $query->delete('enableplugins');
    }
    $this->{topicFilter} = $query->param('filter') ||
      $query->param('topicsearch') || '';
    $this->{genopt} = $query->param('genopt') || '';
    # 'compress' retained for compatibility
    if( defined $query->param('compress') ) {
        my $v = $query->param('compress');
        if ($v =~ /(\w+)/) {
            $this->{outputformat} = $1;
        }
    } elsif (defined $query->param( 'format' )) {
        my $v = $query->param( 'format' ) || '';
        if ($v =~ /(\w+)/) {
            $this->{outputformat} = $1;
        }
    }
    $this->{publishskin} = $query->param('skin') ||
      $query->param('publishskin');
    foreach my $param qw(filter topicsearch genopt compress format) {
        $query->delete($param);
    }
}

sub publishWeb {
    my ($this, $web) = @_;

    $this->{publisher} = Foswiki::Func::getWikiName();
    $this->{web} = $web;

    #don't add extra markup for topics we're not linking too
    # NEWTOPICLINKSYMBOL LINKTOOLTIPINFO
    if (defined $Foswiki::Plugins::SESSION->{renderer}) {
        $Foswiki::Plugins::SESSION->{renderer}->{NEWLINKSYMBOL} = '';
    } else {
        $Foswiki::Plugins::SESSION->renderer()->{NEWLINKSYMBOL} = '';
    }

    my ($hw, $ht) = Foswiki::Func::normalizeWebTopicName(
        $this->{web}, $this->{historyTopic});
    unless (Foswiki::Func::checkAccessPermission(
        'CHANGE', Foswiki::Func::getWikiName(), undef, $ht, $hw)) {
        die <<TEXT;
Can't publish because $this->{publisher} can't CHANGE
$hw.$ht.
This topic must be editable by the user doing the publishing.
TEXT
    }
    $this->{historyWeb} = $hw;
    $this->{historyTopic} = $ht;

    # Generate the progress information screen (based on the view template)
    my ($header, $footer) = ('', '');
    unless (Foswiki::Func::getContext()->{command_line}) {
        # running from CGI
        if (defined $Foswiki::Plugins::SESSION->{response}) {
            $Foswiki::Plugins::SESSION->generateHTTPHeaders();
            $Foswiki::Plugins::SESSION->{response}->body(
                CGI::start_html( -title => 'Foswiki: Publish'));
        }
        ($header, $footer) = $this->_getPageTemplate();
    }

    # Disable unwanted plugins
    my $enabledPlugins = '';
    my $disabledPlugins = '';
    my @pluginsToEnable;
    if ($this->{enableplugins}) {
        @pluginsToEnable = split(/[, ]+/, $this->{enableplugins});
    }
    foreach my $plugin (keys(%{$Foswiki::cfg{Plugins}})) {
        next unless ref($Foswiki::cfg{Plugins}{$plugin}) eq 'HASH';
        my $enable = $Foswiki::cfg{Plugins}{$plugin}{Enabled};
        if (scalar(@pluginsToEnable) > 0) {
            $enable = grep(/$plugin/, @pluginsToEnable);
            $Foswiki::cfg{Plugins}{$plugin}{Enabled} = $enable;
        }
        $enabledPlugins .= ', '.$plugin if ($enable);
        $disabledPlugins .= ', '.$plugin unless ($enable);
    }

    $Foswiki::cfg{PublishPlugin}{URL} .= '/'
      unless $Foswiki::cfg{PublishPlugin}{URL} =~ m#/$#;

    $this->logInfo("Publisher", $this->{publisher});
    $this->logInfo("Date", Foswiki::Func::formatTime(time()));
    $this->logInfo("{PublishPlugin}{Dir}", $Foswiki::cfg{PublishPlugin}{Dir});
    $this->logInfo("{PublishPlugin}{URL}", $Foswiki::cfg{PublishPlugin}{URL});
    $this->logInfo("Web", $this->{web});
    $this->logInfo("Versions topic", $this->{versionstopic})
      if $this->{versionstopic};
    $this->logInfo("Content Generator", $this->{outputformat});
    $this->logInfo("Config topic", $this->{configtopic})
      if $this->{configtopic};
    $this->logInfo("Skin", $this->{publishskin});
    $this->logInfo("Inclusions", $this->{inclusions});
    $this->logInfo("Exclusions", $this->{exclusions});
    $this->logInfo("Content Filter", $this->{topicFilter});
    $this->logInfo("Generator Options", $this->{genopt});
    $this->logInfo("Enabled Plugins", $enabledPlugins);
    $this->logInfo("Disabled Plugins", $disabledPlugins);

    if ($this->{versionstopic}) {
        $this->{topicVersions} = {};
        my ($vweb, $vtopic) = Foswiki::Func::normalizeWebTopicName(
            $web, $this->{versionstopic});
        die "Versions topic $vweb.$vtopic does not exist"
          unless Foswiki::Func::topicExists($vweb, $vtopic);
        my ($meta, $text) = Foswiki::Func::readTopic($vweb, $vtopic);
        $text = Foswiki::Func::expandCommonVariables(
            $text, $vtopic, $vweb, $meta);
        my $pending;
        my $count = 0;
        foreach my $line (split(/\r?\n/, $text)) {
            if (defined $pending) {
                $line =~ s/^\s*//;
                $line = $pending . $line;
                undef $pending;
            }
            if ($line =~ s/\\$//) {
                $pending = $line;
                next;
            }
            if ($line =~ /^\s*\|\s*(.*?)\s*\|\s*(?:\d\.)?(\d+)\s*\|\s*$/) {
                my ($t, $v) = ($1, $2);
                ($vweb, $vtopic) = Foswiki::Func::normalizeWebTopicName(
                    $web, $t);
                $this->{topicVersions}->{"$vweb.$vtopic"} = $v;
                $count++;
            }
        }
        die "Versions topic $vweb.$vtopic contains no topic versions"
          unless $count;
    }

    my @templatesWanted = split(/,/, $this->{templatesWanted});

    foreach my $template (@templatesWanted) {
        next unless $template;
        $this->{templatesReferenced}->{$template} = 1;
        my $dir = $Foswiki::cfg{PublishPlugin}{Dir}.
          $this->_dirForTemplate($template);

        my $generator = 'Foswiki::Plugins::PublishPlugin::'.
          $this->{outputformat};
        eval 'use '.$generator;
        unless ($@) {
            eval {
                $this->{archive} =
                  $generator->new($dir, $this->{web}, $this->{genopt},
                                  $this, TWiki::Func::getCgiQuery());
            };
        }
        if ($@ || (!$this->{archive})) {
            die "Failed to initialise '$this->{outputformat}' ($generator) generator: <pre>$@</pre>\n",$footer;
        }
        $this->publishUsingTemplate($template);
    }

    # check the templates referenced, and that everything referenced
    # has been generated.
    my @templatesReferenced = sort keys %{$this->{templatesReferenced}};
    @templatesWanted = sort @templatesWanted;

    my @difference = arrayDiff(\@templatesReferenced, \@templatesWanted); 
    if ($#difference > 0) {
        $this->logInfo("Templates Used", join(",", @templatesReferenced));
        $this->logInfo("Templates Specified", join(",", @templatesWanted));
        $this->logWarn(<<BLAH);
There is a difference between the templates you specified and what you
needed. Consider changing the TEMPLATES setting so it has all Templates
Used.
BLAH
    }

    my $landed = $this->{archive}->close();

    $this->logInfo("Published To",<<LINK);
<a href="$Foswiki::cfg{PublishPlugin}{URL}$landed">$landed</a>
LINK
    my ($meta, $text) =
      Foswiki::Func::readTopic($this->{historyWeb}, $this->{historyTopic});
    $text =~ s/(^|\n)---\+ Last Published\n.*$//s;
    Foswiki::Func::saveTopic(
        $this->{historyWeb}, $this->{historyTopic}, $meta,
        "$text---+ Last Published\n$this->{history}\n",
        { minor => 1, forcenewrevision => 1 });
    my $url = Foswiki::Func::getScriptUrl(
        $this->{historyWeb}, $this->{historyTopic}, 'view');
    $this->logInfo("History saved in", "<a href='$url'>$url</a>");

    Foswiki::Plugins::PublishPlugin::_display($footer);
}

# get a template for presenting output / interacting (*not* used
# for published content)
sub _getPageTemplate {
    my ($this) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $topic = $query->param('publishtopic') || $this->{session}->{topicName};
    my $tmpl = Foswiki::Func::readTemplate('view');

    $tmpl =~ s/%META{.*?}%//g;
    for my $tag qw( REVTITLE REVARG REVISIONS MAXREV CURRREV ) {
        $tmpl =~ s/%$tag%//g;
    }
    my ($header, $footer) = split(/%TEXT%/, $tmpl);
    $header = Foswiki::Func::expandCommonVariables(
        $header, $topic, $this->{web} );
    $header = Foswiki::Func::renderText( $header, $this->{web} );
    $header =~ s/<nop>//go;
    Foswiki::Func::writeHeader();
    Foswiki::Plugins::PublishPlugin::_display $header;

    $footer = Foswiki::Func::expandCommonVariables( $footer, $topic,
                                                  $this->{web} );
    $footer = Foswiki::Func::renderText( $footer, $this->{web} );
    return ($header, $footer);
}

# from http://perl.active-venture.com/pod/perlfaq4-dataarrays.html
sub arrayDiff {
    my ($array1, $array2) = @_;
    my (@union, @intersection, @difference);
    @union = @intersection = @difference = ();
    my %count = ();
    foreach my $element (@$array1, @$array2) { $count{$element}++ }
    foreach my $element (keys %count) {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
    }
    return @difference;
}

sub logInfo {
    my ($this, $header, $body) = @_;
    Foswiki::Plugins::PublishPlugin::_display(
        CGI::b("$header:&nbsp;"), $body, CGI::br());
    $this->{history} .= "<b> $header </b>$body%BR%\n";
}

sub logWarn {
    my ($this, $message) = @_;
    Foswiki::Plugins::PublishPlugin::_display(
        CGI::span({class=>'twikiAlert'}, $message));
    Foswiki::Plugins::PublishPlugin::_display(CGI::br());
    $this->{history} .= "%ORANGE% *WARNING* $message %ENDCOLOR%%BR%\n";
}

sub logError {
    my ($this, $message) = @_;
    Foswiki::Plugins::PublishPlugin::_display(
        CGI::span({class=>'twikiAlert'}, "ERROR: $message"));
    Foswiki::Plugins::PublishPlugin::_display( CGI::br());
    $this->{history} .= "%RED% *ERROR* $message %ENDCOLOR%%BR%\n";
}

#  Publish the contents of one web using the given template (e.g. view)
sub publishUsingTemplate {
    my ($this, $template) = @_;

    # Get list of topics from this web.
    my @topics = Foswiki::Func::getTopicList($this->{web});

    # Choose template. Note that $template_TEMPLATE can still override
    # this in specific topics.
    my $tmpl = Foswiki::Func::readTemplate($template, $this->{publishskin});
    die "Couldn't find template\n" if(!$tmpl);
	my $filetype = _filetypeForTemplate($template);

    # Attempt to render each included page.
    my %copied;
    foreach my $topic (@topics) {
        next if $topic eq $this->{historyTopic}; # never publish this
        try {
            my $dispo = '';
            if( $this->{inclusions} && $topic !~ /^($this->{inclusions})$/ ) {
                $dispo = 'not included';
            } elsif( $this->{exclusions} &&
                       $topic =~ /^($this->{exclusions})$/ ) {
                $dispo = 'excluded';
            } else {
                my $rev = $this->publishTopic(
                    $topic, $filetype, $template, $tmpl, \%copied) || '0';
                $dispo = "Rev $rev published";
            }
            $this->logInfo($topic, $dispo);
        } catch Error::Simple with {
            my $e = shift;
            $this->logError("$topic not published: ".($e->{-text}||''));
        };
    }
}

#  Publish one topic from web.
#   * =$this->{web}= - which web to publish
#   * =$topic= - which topic to publish
#   * =$filetype= - which filetype (pdf, html) to use as a suffix on the file generated

#   * =\%copied= - map of copied resources to new locations
sub publishTopic {
    my ($this, $topic, $filetype, $template, $tmpl, $copied) = @_;

    # Read topic data.

    my ($meta, $text);
    my $publishedRev = $this->{topicVersions}
      ? $this->{topicVersions}->{"$this->{web}.$topic"}
        : undef;

    ($meta, $text) = Foswiki::Func::readTopic(
        $this->{web}, $topic, $publishedRev );
    unless ($publishedRev) {
        my $d;
        ( $d, $d, $publishedRev, $d ) =
          Foswiki::Func::getRevisionInfo($this->{web}, $topic);
    }

    unless( Foswiki::Func::checkAccessPermission( "VIEW", $this->{publisher},
                                                $text, $topic, $this->{web})) {
        $this->logError("View access to $this->{web}.$topic denied");
        return;
    }

    if ( $this->{topicFilter} && $text =~ /$this->{topicFilter}/ ) {
        $this->logInfo($topic, "excluded by filter");
        return;
    }

    # clone the current session
    my $oldSession = $Foswiki::Plugins::SESSION;
    my $query = Foswiki::Func::getCgiQuery();
    $query->param('topic', "$this->{web}.$topic");

    if (defined &Foswiki::Func::pushTopicContext) {
        Foswiki::Func::pushTopicContext($this->{web}, $topic);
    } else {
        # Create a new session so that the contexts are correct. This is
        # really, really inefficient, but is essential to maintain correct
        # prefs if we don't have a modern Func
        my $twiki = new Foswiki($this->{publisher}, $query);
        $Foswiki::Plugins::SESSION = $twiki;
    }

    # Because of Item5388, we have to re-read the topic to get the
    # right session in the $meta. This could be done by patching the
    # $meta object, but this should be longer-lasting.
    # $meta has to have the right session otherwise $WEB and $TOPIC
    # won't work in %IF statements.
    ($meta, $text) = Foswiki::Func::readTopic(
        $this->{web}, $topic, $publishedRev );

    # Allow a local definition of VIEW_TEMPLATE to override the
    # template passed in (unless this is disabled by a global option)
    my $override =
      Foswiki::Func::getPreferencesValue( 'VIEW_TEMPLATE' );
    if ($override) {
        $tmpl = Foswiki::Func::readTemplate(
            $override, $this->{publishskin}, $this->{web});
        $this->logInfo($topic, "has a VIEW_TEMPLATE '$override'");
    }

    my ($revdate, $revuser, $maxrev);
    ($revdate, $revuser, $maxrev) = $meta->getRevisionInfo();
    if (ref($revuser)) {
        $revuser = $revuser->wikiName();
    }

    # Expand and render the topic text
    $text = Foswiki::Func::expandCommonVariables(
        $text, $topic, $this->{web}, $meta);

    my $newText = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $text )) {
        if( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newText = '' unless( $tagSeen );
            $tagSeen = 1;
        } elsif( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        } elsif( $publish ) {
            $newText .= $s;
        }
    }
    $text = $newText;

    # Expand and render the template
    $tmpl = Foswiki::Func::expandCommonVariables(
        $tmpl, $topic, $this->{web}, $meta);

    # Inject the text into the template
    $tmpl =~ s/%TEXT%/$text/g;

    # legacy
    $tmpl =~ s/<nopublish>.*?<\/nopublish>//gs;

    $tmpl =~ s/.*?<\/nopublish>//gs;
    $tmpl =~ s/%MAXREV%/$maxrev/g;
    $tmpl =~ s/%CURRREV%/$maxrev/g;
    $tmpl =~ s/%REVTITLE%//g;

    $tmpl = Foswiki::Func::renderText($tmpl, $this->{web});

    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;

    # Remove <base.../> tag
    $tmpl =~ s/<base[^>]+\/>//i;
    # Remove <base...>...</base> tag
    $tmpl =~ s/<base[^>]+>.*?<\/base>//i;

    # Clean up unsatisfied WikiWords.
    $tmpl =~ s/<span class="twikiNewLink">(.*?)<\/span>/
      $this->_handleNewLink($1)/ge;

    # Copy files from pub dir to rsrc dir in static dir.
    my $hs = $ENV{HTTP_HOST} || "localhost";

    # Find and copy resources attached to the topic
    my $pub = Foswiki::Func::getPubUrlPath();
    $tmpl =~ s!(['"])($Foswiki::cfg{DefaultUrlHost}|https?://$hs)?$pub/(.*?)\1!
      $1.$this->_copyResource($3, $copied).$1!ge;

    my $ilt;

    # Modify local links relative to server base
    $ilt = $Foswiki::Plugins::SESSION->getScriptUrl(0, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify absolute topic links.
    $ilt = $Foswiki::Plugins::SESSION->getScriptUrl(1, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify topic-relative TOC links to strip out parameters (but not anchor)
    $tmpl =~ s!href=(["'])\?.*?(\1|#)!href=$1$2!g;

    # replace any external template references
    $tmpl =~ s!href=["'](.*?)\?template=(\w*)(.*?)["']!
      $this->_rewriteTemplateReferences($tmpl, $1, $2, $3)!e;

    my $extras = 0;

    # Handle image tags using absolute URLs not otherwise satisfied
    $tmpl =~ s!(<img\s+.*?\bsrc=)(["'])(.*?)\2(.*?>)!
      $1.$2.$this->_handleURL($3,\$extras).$2.$4!ge;

    $tmpl =~ s/<nop>//g;

    # Write the resulting HTML.
    $this->{archive}->addString( $tmpl, $topic.$filetype);

    $Foswiki::Plugins::SESSION = $oldSession; # restore twiki object

    return $publishedRev;
}

# rewrite 
#   Topic?template=viewprint%REVARG%.html?template=viewprint%REVARG%
# to
#   _viewprint/Topic.html
#
#   * =$this->{web}=
#   * =$tmpl=
#   * =$topic=
#   * =$template=
# return
#   * 
# side effects

sub _rewriteTemplateReferences {
    my ($this, $tmpl, $topic, $template, $redundantduplicate) = @_;
    # for an unknown reason, these come through with doubled up template= arg
    # e.g.
    # http://.../site/instance/Web/WebHome?template=viewprint%REVARG%.html?template=viewprint%REVARG%
    #$link:
    # Web/ContactUs?template=viewprint%REVARG%.html? "

    my $newLink = $Foswiki::cfg{PublishPlugin}{URL}.
      $this->_dirForTemplate($template)."/".$this->{web}.'/'.
        $topic._filetypeForTemplate($template);
    $this->{templatesReferenced}->{$template} = 1;
	return "href='$newLink'";
}

# Where alternative templates (e.g. viewprint) renderings end up
# This gets appended onto puburl and pubdir
# The web is prefixed before this.
# Do not prepend with a /
sub _dirForTemplate {
    my ($this, $template) = @_;
    return '' if ($template eq 'view');
    return $template unless $this->{templateLocation};
    return "$this->{templateLocation}/$template";
}

# SMELL this needs to be table driven
sub _filetypeForTemplate {
	my ($template) = @_;
	return '.pdf' if ($template eq 'viewpdf');
	return '.html';
}

#  Copy a resource (image, style sheet, etc.) from twiki/pub/%WEB% to
#   static HTML's rsrc directory.
#   * =$this->{web}= - name of web
#   * =$rsrcName= - name of resource (relative to pub/%WEB%)
#   * =\%copied= - map of copied resources to new locations
sub _copyResource {
    my ($this, $rsrcName, $copied) = @_;

    # Trim the resource name, as they can sometimes pick up whitespaces
    $rsrcName =~ /^\s*(.*?)\s*$/;
    $rsrcName = $1;

    # SMELL WARNING
    # This is covers up a case such as where rsrcname comes through like 
    # configtopic=PublishTestWeb/WebPreferences/favicon.ico
    # this should be just WebPreferences/favicon.ico
    # I've searched for hours and so here's a workaround
    if ($rsrcName =~ m/configtopic/) {
        $this->logError("rsrcName '$rsrcName' contains literal 'configtopic'");
        $rsrcName =~ s!.*?/(.*)!$this->{web}/$1!;
        $this->logError("--- FIXED UP to $rsrcName");
    }

    # See if we've already copied this resource.
    unless (exists $copied->{$rsrcName}) {
        # Nope, it's new. Gotta copy it to new location.
        # Split resource name into path (relative to pub/%WEB%) and leaf name.
        my $file = $rsrcName;
        $file =~ s(^(.*)\/)()o;
        my $path = "";
        if ($rsrcName =~ "/") {
            $path = $rsrcName;
            $path =~ s(\/[^\/]*$)()o; # path, excluding the basename
        }
        # Copy resource to rsrc directory.
        my $pubDir = Foswiki::Func::getPubDir();
        if ( -r "$pubDir/$rsrcName" ) {
            $this->{archive}->addDirectory( "rsrc" );
            $this->{archive}->addDirectory( "rsrc/$path" );
            $this->{archive}->addFile( "$pubDir/$rsrcName" , "rsrc/$path/$file" );
            # Record copy so we don't duplicate it later.
            my $destURL = "rsrc/$path/$file";
            $destURL =~ s!//!/!g;
            $copied->{$rsrcName} = $destURL;
        } else {
            $this->logError("$pubDir/$rsrcName is not readable");
        }

        # check css for additional resources, ie, url()
        if ($rsrcName =~ /\.css$/) {
            my @moreResources = ();
            if (open(F, "$pubDir/$rsrcName")) {
                local $/;
                my $data = <F>;
                close(F);
                $data =~ s#\/\*.*?\*\/##gs; # kill comments
                foreach my $line (split(/\r?\n/, $data)) {
                    if ($line =~ /url\(["']?(.*?)["']?\)/) {
                        push @moreResources, $1;
                    }
                }
                my $pub = Foswiki::Func::getPubUrlPath();
                foreach my $resource (@moreResources) {
                    # recurse
                    if ($resource !~ m!^/!) {
                        # if the url is not absolute, assume it's
                        # relative to the current path
                        $resource = $path.'/'.$resource;
                    } else {
                        if ($resource =~ m!$pub/(.*)!) {
                            my $old = $resource;
                            $resource = $1;
                        }
                    }
                    $this->_copyResource($resource, $copied);
                }
            }
        }
    }
    return $copied->{$rsrcName} if $copied->{$rsrcName};
    $this->logError("MISSING RESOURCE $rsrcName");
    return "MISSING RESOURCE $rsrcName";
}

sub _topicURL {
    my( $this, $path ) = @_;
    my $extra = '';

    if( $path && $path =~ s/([#\?].*)$// ) {
        $extra = $1;
        # no point in passing on script params; we are publishing
        # to static HTML.
        $extra =~ s/\?.*?(#|$)/$1/;
    }

    $path ||= $Foswiki::cfg{HomeTopicName};
    $path .= $Foswiki::cfg{HomeTopicName} if $path =~ /\/$/;

    # Normalise
    $this->{web} = join('/', split( /[\/\.]+/, $this->{web} ));
    $path = join('/', split( /[\/\.]+/, $path ));

    # make a path relative to the web
    $path = File::Spec->abs2rel( $path, $this->{web} );
    $path .= '.html';

    return $path.$extra;
}

sub _handleURL {
    my( $this, $src, $extras ) = @_;

    return $src unless $src =~ m!^([a-z]+):([^/:]*)(:\d+)?(/.*)$!;

    my $data;
    if (defined(&Foswiki::Func::getExternalResource)) {
        my $response = Foswiki::Func::getExternalResource($src);
        return $src if $response->is_error();
        $data = $response->content();
    } else {
        my $protocol = $1;
        my $host = $2;
        my $port = $3;
        my $path = $4;
        $data = $Foswiki::Plugins::SESSION->{net}->getUrl(
            $protocol, $host, $port, $path);
    }

    # Note: no extension; rely on file format.
    # Images are pretty good that way.
    my $file = '___extra'.$$extras++;
    $this->{archive}->addDirectory( "rsrc" );
    $this->{archive}->addString( $data, "rsrc/$file" );

    return 'rsrc/'.$file;
}

# Returns a pattern that will match the HTML used to represent an
# unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
# SMELL: another case for a WysiwygPlugin-style rendering engine
sub _handleNewLink {
    my ($this, $link) = @_;
    $link =~ s!<a .*?>!!gi;
    $link =~ s!</a>!!gi;
    return $link;
}

1;
__END__
#
# Copyright (C) 2001 Motorola
# Copyright (C) 2001-2007 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2002, Eric Scouten
# Copyright (C) 2005-2008 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
#
# Removal of this notice in this or derivatives is forbidden.
