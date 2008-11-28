# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Oliver Krueger, KontextWork
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
# For more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.


package TWiki::Plugins::FirefoxBoosterPlugin;
use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Booster speed for Firefox2 rendering by putting css/js together';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'FirefoxBoosterPlugin';


sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{FirefoxBoosterPlugin}{Debug} || 0;

    # Plugin correctly initialized
    return 1;
}

sub completePageHandler {
    my ( $text, $header ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::completePageHandler()" ) if $debug;

    # only do magic if there is a Firefox on the other side
    if ( $ENV{"HTTP_USER_AGENT"} =~ m/firefox.2/i ) {

      TWiki::Func::writeDebug( "- ${pluginName}::completePageHandler: Firefox2 detected." ) if $debug;

      # import javascript
      $text =~ s/(<script\s+type=.text\/javascript.\s+src=[^>]+><\/script>)/&importJavascript($1)/gei;

      # import css via <link>
      my $praefix = '<style type="text/css"><!-- ' . "\n";
      my $suffix  = "\n--></style>";
      $text =~ s/<link\s+rel=.stylesheet.\s+href=["']?(.*?)["']?\s+type=["']?text\/css["']?[^>]*?>/&importStylesheet($1,$praefix,$suffix)/gei;

      # search <style>-tags for @import directives
      $text =~ s/(<style[^>]*?>)(.*?)(<\/style>)/&doStyleContainer($2,$1,$3)/geism;
      # might be done better with recursive regexes

    }

    $_[0] = $text;
    return $text;
}

sub readFile {
    my $name = shift;
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless( defined( $data ));
    return $data;
}


sub importJavascript {
    my $text = $_[0];

    # determine filename from url
    $text    =~ m/src=["'](.*?)["']/i;
    my $file = $1;
    my $dir  = $TWiki::cfg{PubDir};
    my $url  = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{PubUrlPath};
    $file    =~ s/$url/$dir/ge;

    # read file
    my $fileContent = readFile( $file );

    # return container
    return '<script type="text/javascript"><!-- ' . "\n" . $fileContent . "\n//-->\n</script>\n";
}

sub parseStylesheet {
    my $css = $_[0];
    $css =~ s/(.*?)\@import\s+url\(["']?(.*?)["']?\).*?;(.*)/&importStylesheet($2,$1,$3)/ge;
    return $css;
}

sub rewriteUrls {
    my ( $css, $base ) = @_;
    my $host = $TWiki::cfg{DefaultUrlHost};
    my $pub  = $TWiki::cfg{PubUrlPath};

    # rewrite /my/path/file.css
    $css =~ s/url\(["']?\/([^;]*?)["']?\)/url('$host\/$1')/g;

    # rewrite file.css
    $css =~ s/url\(["']?([^\/][^:]*?)["']?\)/url('$base$1')/g;

    return $css;
}

sub importStylesheet {
    my ( $url, $praefix, $suffix ) = @_;
    my $retval = "";
    my $file   = "";
    my $dir    = $TWiki::cfg{PubDir};

    if ( $url =~ m/^http/ ) {
      # url with host
      $file             = $url;
      my $twiki_pub_url = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{PubUrlPath};
      $file             =~ s/$twiki_pub_url/$dir/ge;
    } else {
      # url without host
      $file             = $url;
      my $twiki_pub_url = $TWiki::cfg{PubUrlPath};
      $file             =~ s/$twiki_pub_url/$dir/ge;
    }

    if ( $file ) {
      my $fileContent = readFile( $file );

      # determine current base path and rewrite urls
      $url    =~ m/^(.*\/)[^\/]+$/;
      $retval = rewriteUrls( $fileContent, $1 );

      # recursion
      $retval = parseStylesheet( $retval );
      # SMELL: We should maintain a list of visited urls to prevent loops
    }

    return $praefix . $retval . $suffix;
}

sub doStyleContainer {
    my ( $content, $praefix, $suffix ) = @_;

    # import css via @import
    $content =~ s/\@import\s+url\(["']?(.*?)["']?\).*?;/&importStylesheet($1,"","")/gei;

    return $praefix . $content . $suffix;
}

1;
