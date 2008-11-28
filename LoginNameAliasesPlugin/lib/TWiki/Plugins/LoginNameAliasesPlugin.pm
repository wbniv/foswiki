# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# LoginNameAliasesPlugin 
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# Copyright (C) 2004 by Carnegie Mellon University
#
# CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
# CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
# ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
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
# =========================

# =========================

package TWiki::Plugins::LoginNameAliasesPlugin;

# =========================
use vars qw($web $topic $user $installWeb $VERSION $RELEASE $pluginName);

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'LoginNameAliasesPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    # Plugin correctly initialized

    # plugin has already done its thing by the time this is called.
    my $debug = TWiki::Func::getPreferencesFlag( "LOGINNAMEALIASESPLUGIN_DEBUG" );
    TWiki::Func::writeDebug(
    "- TWiki::Plugins::${pluginName}::initPlugin($web.$topic ) is OK" ) 
       if ($debug);
    return 1;
}

# =========================
sub earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}

# =========================

# Plugin preferences are not yet  read when initializeUserHandler is called, 
# so we can't use the usual  Func.pm calls.  It seems like the important thing
# is to have preferences get parsed "as expected" (i.e. exactly like they do 
# on other topic pages),  so we'll take the risk of something changing out 
# from under us and use functions in the Pref module to do much of the
# dirty work.


sub initializeUserHandler
{

# for security reasons, immediately return unless this variable is set 
# in TWiki.cfg

    return "" unless ($TWiki::useLoginNameAliasesPlugin);

# By default, the logfile is kept in the plugin directory.  Switch the 
# comments around to have the logfile stored with the other logs

 my $logFile = TWiki::Func::getPubDir() . "/TWiki/$pluginName/_logfile.txt";
# my $logFile = $TWiki::logDir . "/LoginNameAliasesLog.txt";


  my $loginName = $_[0];

# $_[0] is very possibly undef. If so, set our $loginName to "", so we can
# print debugging info w/o generating warnings.

 $loginName = "" unless defined($loginName);
 $original_loginName = $loginName;  # will need this later on
 

# all returned login names go through the TWiki security filter.  set it
# here so we can change this (use some other filter) in one place if needed

    my $sec_filter = $TWiki::securityFilter;

# read in the topic which has the configuration information and aliases
# list and process it.  Hardcode the web to 'TWiki' since we aren't passed
# $installWeb.

    my $text = TWiki::Func::readTopicText('TWiki', $pluginName, "", 1);
    
# Get our settings using routines in TWiki::Prefs

    my %prefs = ();
    my $parser = TWiki::Prefs::Parser->new();

    foreach my $s (@{$parser->parseText($text)}) {
            my $key = $s->[0];
            my $val = $s->[1];
            # remove leading/trailing whitespace (this may not be necessary)
            $key =~ s/^\s+//;
            $key =~ s/\s+$//;
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            if (($key eq 'USE_ALIASES') || ($key eq 'DEBUG') ||
                ($key eq 'RETURN_NOTHING_IF_UNCHANGED') ||
                ($key eq 'LOGGING')) {
               $val = TWiki::Prefs::formatAsFlag($val);
            }
            $prefs{$key} = $val;
    }

# Assume TWiki is being called from a script (mailnotify, etc) 
# if REMOTE_ADDR is not set. In that case, log a debug message 
# and exit.
  
  unless ($ENV{'REMOTE_ADDR'}) {
        TWiki::Func::writeDebug( "- $pluginName REMOTE_ADDR not set. Returning." )
            if ($prefs{'DEBUG'});
        return "";
  }
          
  TWiki::Func::writeDebug( "- $pluginName prefs read. user: $original_loginName" )
                             if ($prefs{'DEBUG'});
                             
  if ($prefs{'DEBUG'}) {
    TWiki::Func::writeDebug( "- $pluginName prefs: " );
    foreach my $p (keys %prefs) {
        TWiki::Func::writeDebug( "- $pluginName  pref $p is  $prefs{$p}");
    }
    TWiki::Func::writeDebug( "- logFile: $logFile");
  }


# take care of case where $loginName is blank or $loginName
# would be blank after security filter is applied

    my $tmpName = $loginName;
    $tmpName =~ s/$sec_filter//go;
    unless ($tmpName) {
       my $u = $prefs{'MAP_BLANK_USER'};
       if ($u) {
          $u =~ s/$sec_filter//go;
          _dologging($logFile, $original_loginName, $u) if ($prefs{'LOGGING'});
          return $u;
       } else {
          _dologging($logFile, $original_loginName, "") if ($prefs{'LOGGING'});
          return "";
       }
    }       



#   now process aliases if necessary

    if ($prefs{'USE_ALIASES'}) {

#   an alias entry is a single line with the following form:
#   <multiple of 3 spaces>*<space>ALIAS:<space>alias_value<space>username

        foreach my $l (split(/\n/,$text)) {
            my ($a,$u) = ($l =~ m/^\t+\*\sALIAS:\s(\S+)\s(\S+)\s*$/);
            if (($a && $u) && ($a eq $loginName)) {
              TWiki::Func::writeDebug( "ALIAS found:  $a -->  $u" ) 
                             if ($prefs{'DEBUG'});
                $u =~ s/$sec_filter//go;
                _dologging($logFile, $loginName, $u) if ($prefs{'LOGGING'});
                return $u;
           }
        }
    }


# Remove prefixes and suffixes if set

  if ($prefs{'REMOVE_PREFIX'}) {
     my $p = quotemeta($prefs{'REMOVE_PREFIX'});
     my $tmp = $loginName if ($prefs{'DEBUG'});
     $loginName =~  s/^$p//;
     TWiki::Func::writeDebug( "REMOVE_PREFIX  $tmp -->  $loginName" )
                              if ($prefs{'DEBUG'});
     }

  if ($prefs{'REMOVE_SUFFIX'}) {
     my $s = quotemeta($prefs{'REMOVE_SUFFIX'});
     my $tmp = $loginName if ($prefs{'DEBUG'});
     $loginName =~ s/$s$//;
     TWiki::Func::writeDebug( "REMOVE_SUFFIX  $tmp -->  $loginName" ) 
                              if ($prefs{'DEBUG'});
     }

# If our substitutions nuked the entire loginName, do the MAP_BLANK_USER
# thing again

    $tmpName = $loginName;
    $tmpName =~ s/$sec_filter//go;
    unless ($tmpName) {
       my $u = $prefs{'MAP_BLANK_USER'};
       if ($u) {
          $u =~ s/$sec_filter//go;
          _dologging($logFile, $original_loginName, $u) if ($prefs{'LOGGING'});
          return $u;
       } else {
          _dologging($logFile, $original_loginName, "") if ($prefs{'LOGGING'});
          return "";
       }
    }       


# Do registration check and return if found
# This assumes that $doMapUserToWikiName is true in TWiki.cfg.
# Looks for key in %TWiki::userToWikiList

  if ($prefs{'MAP_UNREGISTERED'}) {
     unless (exists($TWiki::userToWikiList{$loginName})) {
             $loginName = $prefs{'MAP_UNREGISTERED'};
             $loginName =~  s/$sec_filter//go;
             _dologging($logFile, $original_loginName, $loginName) if ($prefs{'LOGGING'});
             return $loginName;
     }
  }

#
# at this point, we have a non-blank login-name, either unchanged from the
# original or transformed by one or more of the PREFIX/SUFFIX removals.
# 


if (($prefs{'RETURN_NOTHING_IF_UNCHANGED'}) &&
     ($loginName eq $original_loginName)) {
     _dologging($logFile,  $original_loginName, "") 
                           if ($prefs{'LOGGING'});     
     return "";
  } else {
     $loginName =~ s/$sec_filter//go;
     _dologging($logFile, $original_loginName, $loginName) 
                         if ($prefs{'LOGGING'});    
     return $loginName;
  }

}

# Optional logging of user information before and after plugin is run.
# This can be useful to track down authorization issues, since the TWiki
# logs only have the user information after it has been changed by the
# plugin 

sub _dologging {
    my ($logfile, $orig_name, $new_name) = @_;
    my $ip = $ENV{'REMOTE_ADDR'} ? $ENV{'REMOTE_ADDR'} : "";
    my $rem_user = defined($ENV{'REMOTE_USER'}) ? $ENV{'REMOTE_USER'} : "";
    my $now = TWiki::Func::formatTime(time(), 'http', 'servertime');
    local *ALIASPLUGINLOG;
    # log a warning if we can't open the logfile
    unless (open(ALIASPLUGINLOG, ">>$logfile")) {
        TWiki::Func::writeWarning(
          "- $pluginName: Unable to open logfile: $logfile" );
        return 0;
    }
    print(ALIASPLUGINLOG
          "| $now  |  $ip  |  $rem_user  |  $orig_name  |  $new_name  |\n");
    close ALIASPLUGINLOG;
    return 1;
}

1;
