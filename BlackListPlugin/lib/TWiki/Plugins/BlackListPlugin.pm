# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2007 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# Q&D implementation of backlist handler. Black sheep get a
# timeout and a message

# =========================
package TWiki::Plugins::BlackListPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug %cfg
        $userScore $isBlackSheep
    );
use vars qw( %TWikiCompatibility );

BEGIN {
# This should always be $Rev: 13186 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 13186 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'any TWiki';

    $pluginName = 'BlackListPlugin';  # Name of this Plugin
    %cfg =
        (
            "ptReg"   => 10,
            "ptChg"   => 5,
            "ptView"  => 1,
            "ptRaw"   => 30,
            "ptLimit" => 100,
            "period"  => 300,
        );
    $userScore = "N/A";
    $isBlackSheep = 0;
    $noFollowAge = 0;
    $topicAge = 0;
    $urlHost = "initialized_later";
}

# =========================
sub writeDebug
{
    TWiki::Func::writeDebug("$pluginName - " . $_[0]) if $debug;
}

# =========================
sub writeDebugTimes
{
    TWiki::Func::writeDebugTimes("$pluginName - " . $_[0]) if $debug;
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    my $cgiQuery = TWiki::Func::getCgiQuery();

    # Registration protection
    if( ( $cgiQuery ) && ( $ENV{'SCRIPT_NAME'} ) && ( $ENV{'SCRIPT_NAME'} =~ /^.*\/register/ ) ) {
        my $magic = $cgiQuery->param('rx') || "";
        $magic = "" unless( $magic =~ s/.*?([0-9]+).*/$1/s );
        my $expire = TWiki::Func::getPreferencesValue( "\U$pluginName\E_REGEXPIRE" ) || 0;
        $expire = 0 unless( $expire =~ s/.*?([0-9]+).*/$1/s );
        if( $TWiki::Plugins::VERSION >= 1.1 ) {
            # look at magic number only for register, not for verify, resetPassword or approve
            my $regAction = $cgiQuery->param('action') || "";
            $expire = 0 if( $regAction =~ /^(verify|resetPassword|approve)$/ );
        }
        if( $expire > 0 ) {
            $expire *= 60;
            $expire = time() - $expire;
            my $fileName = _makeFileName( "magic" );
            my $ok = 0;
            foreach( split( /\n/, TWiki::Func::readFile( $fileName ) ) ) {
                 if( /^([0-9]+) ([0-9]+)/ ) {
                     my $fmagic = $1;
                     my $ftime = $2;
                     if( ( $fmagic eq $magic ) && ( $ftime > $expire ) ) {
                         $ok = 1;
                         last;
                     }
                }
            }
            unless( $ok ) {
                # magic number expired
                _writeLog( "REGEXPIRE: Magic $magic is missing, bad or expired" );
                my $msg = TWiki::Func::getPreferencesValue( "\U$pluginName\E_REGMESSAGE" ) ||
                      "Registration failed, please try again.";
                $ok = "[[%SYSTEMWEB%.UserRegistration][OK]]";
                my $url = TWiki::Func::getOopsUrl( $web, $topic, "oopsblacklist", $msg, $ok );
                print $cgiQuery->redirect( $url );
                exit 0; # should never reach this
            }
        }
    }

    # initialize for rel="nofollow" links
    $urlHost = TWiki::Func::getUrlHost();
    $noFollowAge = TWiki::Func::getPreferencesValue( "\U$pluginName\E_NOFOLLOWAGE" ) || 0;
    $noFollowAge = 0 unless( $noFollowAge =~ s/.*?(\-?[0-9]*.*)/$1/s );
    if( $noFollowAge > 0 ) {
        $noFollowAge *= 3600;
        my( $date ) = TWiki::Func::getRevisionInfo( $web, $topic );
        $topicAge = time() - $date if( $date );
    } 

    # white list
    my $whiteList = _getWhiteListRegex();

    # black list
    my $blackList = TWiki::Func::getPreferencesValue( "\U$pluginName\E_BLACKLIST" ) || "";
    $blackList = join( "|", map { quotemeta } split( /,\s*/, $blackList ) );

    # ban list
    my $remoteAddr = $ENV{'REMOTE_ADDR'}   || "";
    my $scriptName = $ENV{'SCRIPT_NAME'}   || "";
    my $queryString = $ENV{'QUERY_STRING'} || "";
    my $banList = _handleBanList( "read", $remoteAddr );
    $banList = join( "|", map { quotemeta } split( /\n/, $banList ) );

    # black list + ban list regular expression
    my $blackRE = "($blackList";
    $blackRE .= "|" if( $blackList && $banList );
    $blackRE .= "$banList)";

    # black sheep if in black list unless in white list
    $isBlackSheep = 0;
    $userScore = "N/A";
    if( ( $remoteAddr ) && ( $remoteAddr !~ /^$whiteList/ ) ) {
        if( $blackRE ne "()" && $remoteAddr =~ /^$blackRE/ ) {
            # already a black sheep
            $isBlackSheep = 1;
        } else {
            # check for new candidate of black sheep

            my( $c1, $c2, $c3, $c4, $c5, $c6 ) =
                split( /,\s*/, TWiki::Func::getPreferencesValue( "\U$pluginName\E_BANLISTCONFIG" ) );
            $cfg{ "ptReg" }   = $c1 || 10;
            $cfg{ "ptChg" }   = $c2 || 5;
            $cfg{ "ptView" }  = $c3 || 1;
            $cfg{ "ptRaw" }   = $c4 || 30;
            $cfg{ "ptLimit" } = $c5 || 100;
            $cfg{ "period" }  = $c6 || 300;

            $userScore = _handleEventLog( $remoteAddr, $scriptName, $queryString );
            writeDebug( "initPlugin() score: $userScore" );
            if( $userScore > $cfg{ "ptLimit" } ) {
                $isBlackSheep = 1;
                _handleBanList( "add", $remoteAddr );
                _writeLog( "BANLIST add: $remoteAddr, $userScore over limit $cfg{ \"ptLimit\" }" );
            }
        }
    }

    if( $isBlackSheep ) {
        # black sheep identified
        _writeLog( $scriptName );
        # sleep for one minute
        sleep 60 unless( $debug );
        if( $scriptName =~ /oops/ ) {
            # show oops message normal
        } else {
            # other scripts: redirect to oops message
            unless( $cgiQuery ) {
                exit 1; # Force a "500 Internal Server Error" error
            }
            my $msg = TWiki::Func::getPreferencesValue( "\U$pluginName\E_BLACKLISTMESSAGE" ) ||
                      "You are black listed at %WIKITOOLNAME%.";
            my $ok = "[[http://en.wikipedia.org/wiki/Link_spam][OK]]";
            my $url = TWiki::Func::getOopsUrl( $web, $topic, "oopsblacklist", $msg, $ok );
            print $cgiQuery->redirect( $url );
            exit 0; # should never reach this
        }
    }

    # Plugin correctly initialized
    writeDebug( "initPlugin( $web.$topic ) is OK, whiteList $whiteList, blackRE $blackRE" );
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "commonTagsHandler( $_[2].$_[1] )" );

    $_[0] =~ s/%BLACKLISTPLUGIN{(.*?)}%/_handleBlackList( $1, $_[2], $_[1] )/geo;
}

# =========================

# Stop TWiki registering the endRenderingHandler with TWiki::Plugins 1.1
# or later
$TWikiCompatibility{endRenderingHandler} = 1.1;

sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

    writeDebug( "endRenderingHandler( $web.$topic )" );
    postRenderingHandler( @_ );
}

# This handler will only be called by TWiki before TWiki::Plugins 1.1
sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return unless( $noFollowAge );
    $_[0] =~ s/(<a .*?href=[\"\']?)([^\"\'\s]+[\"\']?)(\s*[a-z]*)/_handleNofollowLink( $1, $2, $3 )/geoi;
}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "beforeSaveHandler( $_[2].$_[1] )" );
    # This handler is called by TWiki::Store::saveTopic just before the save action.

    # Bail out unless spam filtering is enabled
    return unless( TWiki::Func::getPreferencesFlag( "\U$pluginName\E_FILTERWIKISPAM" ) );

    # Bail out for excluded topics
    my @arr = split( /,\s*/, TWiki::Func::getPreferencesValue( "\U$pluginName\E_SPAMEXCLUDETOPICS" ) );
    foreach( @arr ) {
        return if( ( /^(.*)/ ) && ( $1 eq "$_[2].$_[1]" ) );
    }

    # exclude white list
    my $whiteList = _getWhiteListRegex();
    my $remoteAddr = $ENV{'REMOTE_ADDR'}   || "";
    return if( $remoteAddr =~ /^$whiteList/ );

    my $spamListRegex = _getSpamListRegex();
    return if( $spamListRegex =~ /\(\)$/ ); # empty list
    if( $_[0] =~ /$spamListRegex/ ) {
        _oopsMessage( "topic", $1, $remoteAddr );
    }

    # check for evil eval() or escape() spam in <script>
    if( $_[0] =~ /<script.*?(eval|escape) *\(.*?<\/script>/gis ) {
        _oopsMessage( "topic", "script eval() or escape()", $remoteAddr );
    }

    # check for 'no changes ... no changes' by ringtones scumbag
    if( $_[0] =~ /no changes \.\.\. no changes/gis ) {
        _oopsMessage( "topic", "ringtones scumbag", $remoteAddr );
    }
}

# =========================
sub beforeAttachmentSaveHandler
{
### my ( $attachmentAttr, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $attachmentAttr = $_[0];
    my $attachmentName = $attachmentAttr->{"attachment"};
    my $tmpFilename    = $attachmentAttr->{"tmpFilename"}
                      || $attachmentAttr->{"file"};  # workaround for TWiki 4.0.2 bug

    # This handler is called by TWiki::Store::saveAttachment just before the save action
    writeDebug( "beforeAttachmentSaveHandler( $_[2].$_[1], $attachmentName )" );

    # Bail out unless spam filtering is enabled
    return unless( TWiki::Func::getPreferencesFlag( "\U$pluginName\E_FILTERWIKISPAM" ) );

    # test only attachments of type .html and a few more
    return unless( $attachmentName =~ m/\.(html?|txt|js|css)$/i );

    # exclude white list
    my $whiteList = _getWhiteListRegex();
    my $remoteAddr = $ENV{'REMOTE_ADDR'}   || "";
    return if( $remoteAddr =~ /^$whiteList/ );

    # check for evil eval() or escape() spam in <script>
    my $text = TWiki::Func::readFile( $tmpFilename );
    if( $text =~ /<script.*?(eval|escape) *\(.*?<\/script>/gis ) {
        _oopsMessage( "html", "script eval() or escape()", $remoteAddr );
    }

    # check for known spam signatures
    my $spamListRegex = _getSpamListRegex();
    return if( $spamListRegex =~ /\(\)$/ ); # empty list
    if( $text =~ /$spamListRegex/ ) {
        _oopsMessage( "html", $1, $remoteAddr );
    }
}

# =========================
sub _oopsMessage
{
    my ( $type, $badword, $remoteAddr ) = @_;

    my $cgiQuery = TWiki::Func::getCgiQuery();
    if( $cgiQuery ) {
        _handleBanList( "add", $remoteAddr );
        _writeLog( "SPAMLIST add: $remoteAddr, $type spam '$badword'" );

        my $msg = TWiki::Func::getPreferencesValue( "\U$pluginName\E_WIKISPAMMESSAGE" ) ||
                  "Spam detected, '%WIKISPAMWORD%' is a banned word and cannot be saved.";
        $msg =~ s/%WIKISPAMWORD%/$badword/;
        my $ok = "[[http://en.wikipedia.org/wiki/Spamdexing][OK]]";
        $url = TWiki::Func::getOopsUrl( $web, $topic, "oopsblacklist", $msg, $ok );
        print $cgiQuery->redirect( $url );
        exit 0; # should never reach this
    }
    # else (unlikely case) force a "500 Internal Server Error" error
    exit 1;
}

# =========================
sub _getWhiteListRegex
{
    my $regex = TWiki::Func::getPreferencesValue( "\U$pluginName\E_WHITELIST" ) || "127.0.0.1";
    $regex = join( "|", map { quotemeta } split( /,\s*/, $regex ) );
    return "($regex)";
}

# =========================
sub _getSpamListRegex
{
    my $refresh = TWiki::Func::getPreferencesValue( "\U$pluginName\E_SPAMREGEXREFRESH" ) || 5;
    $refresh = 1 unless( $refresh =~ s/.*?([0-9]+).*/$1/s );
    $refresh = 1 if( $refresh < 1 );

    my $cacheFile = _makeFileName( "spam_regex" );
    if( ( -e $cacheFile ) && ( ( time() - (stat(_))[9] ) <= ( $refresh * 60 ) ) ) {
        # return cached version if it exists and isn't too old
        return TWiki::Func::readFile( $cacheFile );
    }

    # merge public and local spam list
    my $text = _getSpamMergeText() . "\n" . _handleSpamList( "read", "" );
    $text =~ s/ *\#.*//go;      # strip comments
    $text =~ s/^.*?[ <>].*?$//gom;  # remove all lines that have spaces or HTML <tags>

    # Remove patterns in exclude list
    my $excludeRE = join( '|', map{ quotemeta } split( /[\n\r]+/, _handleExcludeList( "read", "" ) ) );
    $text =~ s/^.*?($excludeRE).*?$//gm if( $excludeRE );

    # Build regex
    $text =~ s/^[\n\r]+//os;
    $text =~ s/[\n\r]+$//os;
    $text =~ s/[\n\r]+/\|/gos;
    $text = "(http://[\\w\\.\\-:\\@/]*?($text))";
    TWiki::Func::saveFile( $cacheFile, $text );
    return $text;
}

# =========================
sub _getSpamMergeText
{
    my $url = TWiki::Func::getPreferencesValue( "\U$pluginName\E_SPAMLISTURL" ) ||
              'http://arch.thinkmo.de/cgi-bin/spam-merge';
    my $refresh = TWiki::Func::getPreferencesValue( "\U$pluginName\E_SPAMLISTREFRESH" ) || 10;
    $refresh = 10 unless( $refresh =~ s/.*?([0-9]+).*/$1/s );
    $refresh = 10 if( $refresh < 10 );

    my $cacheFile = _makeFileName( "spam_merge" );
    if( ( -e $cacheFile ) && ( ( time() - (stat(_))[9] ) <= ( $refresh * 60 ) ) ) {
        # return cached version if it exists and isn't too old
        return TWiki::Func::readFile( $cacheFile );
    }

    # read spam merge list via http
    $url =~ /http\:\/\/(.*?)(\/.*)/;
    my $host = $1;
    my $port = 0;
    my $path = $2;
    my $text = '';
    my $headerAndContent = 1;
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        # TWiki 01 Sep 2004 and older
        $text = TWiki::Net::getUrl( $host, $port, $path );
    } elsif( $TWiki::Plugins::VERSION < 1.11 ) {
        # TWiki 4.0
        $text = $TWiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path );
    } elsif( $TWiki::Plugins::VERSION < 1.12 ) {
        # TWiki 4.1
        $text = $TWiki::Plugins::SESSION->{net}->getUrl( 'http', $host, $port, $path );
    } else {
        # TWiki 4.2
        my $response = TWiki::Func::getExternalResource( $url );
        if( $response->is_error() ) {
            my $msg = "Code " . $response->code() . ": " . $response->message();
            $msg =~ s/[\n\r]/ /gos;
            TWiki::Func::writeDebug( "- $pluginName ERROR: Can't read $url ($msg)" );
            return "#ERROR: Can't read $url ($msg)";
        } else {
            $text = $response->content();
            $headerAndContent = 0;
        }
    }

    if( $headerAndContent ) {
        if( $text =~ /text\/plain\s*ERROR\: (.*)/s ) {
            my $msg = $1;
            $msg =~ s/[\n\r]/ /gos;
            TWiki::Func::writeDebug( "- $pluginName ERROR: Can't read $url ($msg)" );
            return "#ERROR: Can't read $url ($msg)";
        }
        if( $text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s ) {
            unless( $1 == 200 ) {
                TWiki::Func::writeDebug( "- $pluginName ERROR: Can't read $url ($1 $2)" );
                return "#ERROR: Can't read $url ($1 $2)";
            }
        }
    }
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;
    $text =~ s/^.*?\n\n(.*)/$1/os if( $headerAndContent );  # strip header
    unless( $text =~ /.{128}/ ) {
        # spam-merge file is too short, possibly temporary read error
        TWiki::Func::writeDebug( "- $pluginName WARNING: Content of $url is too short, using old cache" );
        TWiki::Func::saveFile(  _makeFileName( "spam_merge_err" ), $text );
        $text = TWiki::Func::readFile( $cacheFile ); # read old cache content
    }
    TWiki::Func::saveFile( $cacheFile, $text );
    return $text;
}


# =========================
sub _handleSpamList
{
    my ( $theAction, $theValue ) = @_;
    my $fileName = _makeFileName( "spam_list", 0 );
    writeDebug( "_handleSpamList( Action: $theAction, value: $theValue, file: $fileName )" );
    my $text = TWiki::Func::readFile( $fileName ) || "# The spam-list is a generated file, do not edit\n";
    if( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;
    }

    my @errorMessages;
    my @infoMessages;
    foreach my $item (split( /,\s*/, $theValue )) {
      $item =~ s/^\s+//;
      $item =~ s/\s+$//;

      if( $theAction eq "add" ) {
        if( $text =~ /\n\Q$item\E\n/s ) {
            push @infoMessages, "Warning: Spam pattern '$item' is already on the list";
            next;
        }
        $text .= "$item\n";
        push @infoMessages, "Note: Added spam pattern '$item'";
        unlink( _makeFileName( "spam_regex" ) ); # remove cache

      } elsif( $theAction eq "remove" ) {
        unless( ( $item ) && ( $text =~ s/(\n)\Q$item\E\n/$1/s ) ) {
            push @errorMessages, "Error: Spam pattern '$item' not found";
            next;
        }
        push @infoMessages, "Note: Removed spam pattern '$item'";
        unlink( _makeFileName( "spam_regex" ) ); # remove cache

      } else {
        # never reach
        return "Error: invalid action '$theAction'";
      }
    }

    if (@errorMessages) {
      writeDebug("spamlist=$text");
      return '<div class="foswikiAlert">' .  join("<br /> ", @errorMessages) . '</div>';

    } else {
      if (@infoMessages) {
        # SMELL: overwrites a concurrent save
        writeDebug("spamlist=$text");
        TWiki::Func::saveFile( $fileName, $text );
        return '<br />' . join( "<br /> ", @infoMessages );

      } else {
        return 'Error: done nothing';
      }
    }
}

# =========================
sub _handleExcludeList
{
    my ( $theAction, $theValue ) = @_;
    my $fileName = _makeFileName( "exclude_list", 0 );
    writeDebug( "_handleExcludeList( Action: $theAction, value: $theValue, file: $fileName )" );
    my $text = TWiki::Func::readFile( $fileName ) || "# The exclude-list is a generated file, do not edit\n";
    if( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;
    }

    my @errorMessages;
    my @infoMessages;
    foreach my $item (split( /,\s*/, $theValue )) {
      $item =~ s/^\s+//;
      $item =~ s/\s+$//;

      if( $theAction eq "add" ) {
        if( $text =~ /\n\Q$item\E\n/s ) {
            push @infoMessages, "Warning: Exclude pattern '$item' is already on the list";
            next;
        }
        $text .= "$item\n";
        push @infoMessages, "Note: Added exclude pattern '$item'";
        unlink( _makeFileName( "spam_regex" ) ); # remove cache

      } elsif( $theAction eq "remove" ) {
        unless( ( $item ) && ( $text =~ s/(\n)\Q$item\E\n/$1/s ) ) {
            push @errorMessages, "Error: Exclude pattern '$item' not found";
            next;
        }
        push @infoMessages, "Note: Removed exclude pattern '$item'";
        unlink( _makeFileName( "spam_regex" ) ); # remove cache

      } else {
        # never reach
        return "Error: invalid action '$theAction'";
      }
    }

    if (@errorMessages) {
      writeDebug("excludelist=$text");
      return '<div class="foswikiAlert">' .  join("<br /> ", @errorMessages) . '</div>';

    } else {
      if (@infoMessages) {
        # SMELL: overwrites a concurrent save
        writeDebug("excludelist=$text");
        TWiki::Func::saveFile( $fileName, $text );
        return '<br />' . join( "<br /> ", @infoMessages );

      } else {
        return 'Error: done nothing';
      }
    }
}

# =========================
sub _handleBlackList
{
    my( $theAttributes, $theWeb, $theTopic ) = @_;
    my $action = TWiki::Func::extractNameValuePair( $theAttributes, "action" );
    my $value  = TWiki::Func::extractNameValuePair( $theAttributes, "value" );
    my $text = "";

    writeDebug( "_handleBlackList( Action: $action, value: $value, topic: $theWeb.$theTopic )" );
    if( $action eq "magic" ) {
        $text = int( rand( 100000 ) ) + 1;
        my $time = time();
        my $expire = TWiki::Func::getPreferencesValue( "\U$pluginName\E_REGEXPIRE" ) || 0;
        $expire = 0 unless( $expire =~ s/.*?([0-9]+).*/$1/s );
        $expire *= 60;
        $expire = $time - $expire;
        my $fileName = _makeFileName( "magic" );
        # read magic file
        my $mtext = TWiki::Func::readFile( $fileName );
        # remove expired numbers
        my @magic = grep { /^[0-9]+ ([0-9]+)/ && ( $1 > $expire ) } split( /[\n\r]+/, $mtext );
        # add new magic number with timestamp
        $magic[++$#magic] = "$text $time";
        TWiki::Func::saveFile( $fileName, join( "\n", @magic )  . "\n" );

    } elsif( $action eq "ban_show" ) {
        $text = _handleBanList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    } elsif( $action eq "spam_show" ) {
        $text = _handleSpamList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    } elsif( $action eq "exclude_show" ) {
        $text = _handleExcludeList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    } elsif( $action eq "spam_show_n" ) {
        $text = _handleSpamList( "read", "" );

    } elsif( $action eq "user_score" ) {
        $text = $userScore;

    } elsif( $action =~ /^(ban_add|ban_remove|spam_add|spam_remove|exclude_add|exclude_remove)$/ ) {
        my $anchor = "#BanList";
        if( "$theWeb.$theTopic" eq "$installWeb.$pluginName" ) {
            my $wikiName = &TWiki::Func::userToWikiName( $user );
            if( TWiki::Func::checkAccessPermission( "CHANGE", $wikiName, "", $pluginName, $installWeb ) ) {
                if( $action eq "ban_add" ) {
                    $text .= _handleBanList( "add", $value );
                    _writeLog( "BANLIST add: $value, by user" );
                } elsif( $action eq "ban_remove" ) {
                    $text .= _handleBanList( "remove", $value );
                    _writeLog( "BANLIST delete: $value by user" );
                } elsif( $action eq "spam_add" ) {
                    $text .= _handleSpamList( "add", $value );
                    $anchor = "#SpamList";
                    _writeLog( "SPAMLIST add: $value, by user" );
                } elsif( $action eq "spam_remove" ) {
                    $text .= _handleSpamList( "remove", $value );
                    $anchor = "#SpamList";
                    _writeLog( "SPAMLIST delete: $value by user" );
                } elsif( $action eq "exclude_add" ) {
                    $text .= _handleExcludeList( "add", $value );
                    $anchor = "#ExcludeList";
                    _writeLog( "EXCLUDELIST add: $value, by user" );
                } else {
                    $text .= _handleExcludeList( "remove", $value );
                    $anchor = "#ExcludeList";
                    _writeLog( "EXCLUDELIST delete: $value by user" );
                }
            } else {
                $text = "Error: You do not have permission to maintain the list";
            }
        } else {
            $text = "Error: For use on $installWeb.$pluginName topic only";
        }
        $text .= " [ [[$theWeb.$theTopic$anchor][OK]] ]";
    }
    return $text;
}

# =========================
sub _handleBanList
{
    my ( $theAction, $theIPs ) = @_;
    my $fileName = _makeFileName( "ban_list", 0 );
    writeDebug( "_handleBanList( Action: $theAction, IP: $theIPs, file: $fileName )" );
    my $text = TWiki::Func::readFile( $fileName ) || "# The ban-list is a generated file, do not edit\n";
    if( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;
    }

    my @errorMessages;
    my @infoMessages;
    foreach my $theIP (split( /,\s*/, $theIPs )) {
      $theIP =~ s/^\s+//;
      $theIP =~ s/\s+$//;

      if( $theAction eq "add" ) {
        unless( ( $theIP ) && ( $theIP =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ ) ) {
            push @errorMessages, "Error: Invalid IP address '$theIP'";
            next;
        }

        if( $text =~ /\n\Q$theIP\E\n/s ) {
            push @infoMessages, "Warning: IP address '$theIP' is already on the list";
            next;
        }

        $text .= "$theIP\n";

        push @infoMessages, "Note: Added IP address '$theIP'";

      } elsif( $theAction eq "remove" ) {
        unless( ( $theIP ) && ( $text =~ s/(\n)\Q$theIP\E\n/$1/s ) ) {
            push @errorMessages, "Error: IP address '$theIP' not found";
            next;
        }
        push @infoMessages, "Note: Removed IP address '$theIP'";

      } else {
        # never reach
        return "Error: invalid action '$theAction'";
      }
    }

    if (@errorMessages) {
      writeDebug("banlist=$text");
      return '<div class="foswikiAlert">' .  join("<br /> ", @errorMessages) . '</div>';

    } else {
      if (@infoMessages) {
        # SMELL: overwrites a concurrent save 
        writeDebug("banlist=$text");
        TWiki::Func::saveFile( $fileName, $text );
        unless( -e "$fileName" ) {
            # assuming save failed because of missing dir
            _makeFileDir();
            TWiki::Func::saveFile( $fileName, $text );
        }
        return '<br />' . join( "<br /> ", @infoMessages );

      } else {
        return 'Error: done nothing';
      }
    }
}

# =========================
sub _handleEventLog
{
    my ( $theIP, $theType, $theQueryString ) = @_;

    # read/update/save event logs
    my $fileName = _makeFileName( "event_log" );
    writeDebug( "_handleEventLog( IP: $theIP, type: $theType, query: $theQueryString )" );
    my $text = TWiki::Func::readFile( $fileName ) || "# The event-list is a generated file, do not edit\n";
    my $time = time();
    $text .= "$time, $theIP, $theType";
    $text .= "__R_A_W__" if( $theQueryString =~ /raw\=/ );
    $text .= "\n";
    my $limit = $time - $cfg{"period"};
    if( ( $text =~ /([0-9]+)/ ) && ( $1  < $time - 8 * $cfg{"period"} ) ) {
        # for efficiency, clean up expired events only once in a while
        my @arr = split( /\n/, $text );
        my $index = 0;
        my $limit = $time - $cfg{"period"};
        foreach( @arr ) {
            if( ( /^([0-9]+)/ ) && ( $1 >= $limit ) ) {
                last;
            }
            $index++;
        }
        $text = "$arr[0]\n";  # keep comment
        $text .= join( "\n", @arr[$index..$#arr] ) if( $index <= $#arr );
        $text .= "\n";
    }
    TWiki::Func::saveFile( $fileName, $text );

    # extract IP addresses of interest and calculate score
    my $score = 0;
    $type = "";
    foreach( grep { / \Q$theIP\E\,/ } split( /\n/, $text ) ) {
        if( ( /^([0-9]+)\,[^\,]+\, ?(.*)/ ) && ( $1 >= $limit ) ) {
            $type = $2;
            if( $type =~ /register/ ) {
                $score += $cfg{"ptReg"};
            }elsif( $type =~ /(save|upload)/ ) {
                $score += $cfg{"ptChg"};
            }elsif( $type =~ /__R_A_W__/ ) {
                $score += $cfg{"ptRaw"};
            } else {
                $score += $cfg{"ptView"};
            }
        }
    }
    return $score;
}

# =========================
sub _makeFileName
{
    my ( $name ) = @_;
    my $dir = TWiki::Func::getPubDir() . "/$installWeb/$pluginName";
    return "$dir/_$name.txt";
}

# =========================
sub _makeFileDir
{
    # Create web directory "pub/$installWeb" if needed
    my $dir = TWiki::Func::getPubDir() . "/$installWeb";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # Create topic directory "pub/$installWeb/$pluginName" if needed
    $dir .= "/$pluginName";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
}

# =========================
sub _writeLog
{
    my ( $theText ) = @_;
    if( TWiki::Func::getPreferencesFlag( "\U$pluginName\E_LOGACCESS" ) ) {
        # FIXME: Call to unofficial function
        $TWiki::Plugins::SESSION > 1.1
          ? $TWiki::Plugins::SESSION->writeLog( "blacklist", "$web.$topic", $theText )
          : TWiki::Store::writeLog( "blacklist", "$web.$topic", $theText );
        writeDebug( "BLACKLIST access, $web/$topic, $theText" );
    }
}

# =========================
sub _handleNofollowLink
{
    my( $thePrefix, $theUrl, $thePostfix ) = @_;

    # Codev.SpamDefeatingViaNofollowAttribute: Add a rel="nofollow" to URL
    my $addRel = 0;
    my $text = "$thePrefix$theUrl$thePostfix";
    $theUrl =~ m/^http/i      && ( $addRel = 1 ); # only for http and hhtps
    $theUrl =~ m/^$urlHost/i  && ( $addRel = 0 ); # not for own host
    $theUrl =~ m/twiki\.org/i && ( $addRel = 0 ); # not for twiki.org
    $thePostfix =~ m/^\s?rel/ && ( $addRel = 0 ); # prevent adding it twice

    $addRel = 0 if( $noFollowAge > 0 && $topicAge > $noFollowAge ); # old topic

    return $text unless( $addRel );
    return "$thePrefix$theUrl rel=\"nofollow\"$thePostfix";
}

# =========================

1;
