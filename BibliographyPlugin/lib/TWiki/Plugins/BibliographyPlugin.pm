# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Antonio Terceiro, asaterceiro@inf.ufrgs.br
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::BibliographyPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug 
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'BibliographyPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}
 
sub readBibliography
{
  # read the references topics:
  my @referencesTopics = @_;

  my %bibliography;
  my ($key, $value, $topic);

  foreach $topic (@referencesTopics)
  {
    TWiki::Func::writeDebug("readBibliography:: reading $topic") if $debug;

    $_ = TWiki::Func::readTopicText($web, $topic, "", 1);
    TWiki::Func::writeDebug($_) if $debug;
    while (m/^\|([^\|]*)\|([^\|]*)\|/gm)
    {
      ($key,$value) = ($1,$2);
      
      # remove leading and trailing whitespaces from $key and from $value
      $key   =~ s/^\s+|\s+$//g; 
      $value =~ s/^\s+|\s+$//g;

      $bibliography{$key} = {  "name" => $value,
                              "cited" => 0,
                              "order" => 0
                            };
      TWiki::Func::writeDebug("Adding key $key") if $debug;
    }
  }

  TWiki::Func::writeDebug("ended reading bibliography topics") if $debug;
  return %bibliography;

}

sub bibliographyAlphaSort
{
  return lc($bibliography{$a}{"name"}) cmp lc($bibliography{$b}{"name"});
}

sub bibliographyOrderSort
{
  return $bibliography{$a}{"order"} <=> $bibliography{$b}{"order"};
}

sub generateBibliography
{
  my ($header, %bibliography) = @_;

  my $list = "<ol> \n";
  foreach $key (sort bibliographyOrderSort (keys %bibliography))
  {
    my $name = $bibliography{$key}{"name"};
    $list .= "<li> $name </li> \n";
  }
  $list .= "</ol> \n";
 
  return TWiki::Func::renderText($header) . "\n" . $list;
}

sub parseArgs
{
  my $args = $_[0];

  # get the typed header. Defaults to the BIBLIOGRAPHYPLUGIN_DEFAULTHEADER setting.
  my $header = &TWiki::Func::getPreferencesValue("BIBLIOGRAPHYPLUGIN_DEFAULTHEADER");
  if ($args =~ m/header="([^"]*)"/)
  {
    $header = $1;
  }

  #get the typed references topic. Defaults do the BIBLIOGRAPHYPLUGIN_DEFAULTBIBLIOGRAPHYTOPIC.
  my $referencesTopics = &TWiki::Func::getPreferencesValue("BIBLIOGRAPHYPLUGIN_DEFAULTBIBLIOGRAPHYTOPIC");
  if ($args =~ m/referencesTopic="([^"]*)"/)
  {
    $referencesTopics = $1;
  }
  @referencesTopics = split(/\s*,\s*/,$referencesTopics);

  # get the typed order. Defaults to BIBLIOGRAPHYPLUGIN_DEFAULTSORTING setting.
  my $order = &TWiki::Func::getPreferencesValue("BIBLIOGRAPHYPLUGIN_DEFAULTSORTING");
  if ($args =~ m/order="([^"]*)"/)
  {
    $order = $1;
  }

  return ($header, $order, @referencesTopics);
}


sub handleCitation
{
  my ($cit, %bibliography) = @_;
  if (exists $bibliography{$cit})
  {
    return "[" . $bibliography{$cit}{"order"}. "]";
  }
  else
  {
    return "[??]";
  }
}

# was startRenderingHandler before. changed to preRenderingHandler as indicated
# in Foswiki:Extensions/DeprecatedHandlers.
sub preRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
    
    my ($header, @referencesTopics, $order);
    if ($_[0] =~ m/%BIBLIOGRAPHY{([^}]*)}%/mg)
    {
      ($header, $order, @referencesTopics) = parseArgs ($1);
      %bibliography = readBibliography (@referencesTopics);
    }
    else
    {
      ($header, $order, @referencesTopics) = parseArgs ("");
      %bibliography= ();
    }

    ######################################################

    # mark cited entries:
    my $i = 1;
    $_ = $_[0];
    while (m/%CITE(INLINE)?{([^}]*)}%/mg)
    {
      if ($1) {
        # was a %CITEINLINE{...}%:
        if (not (exists $bibliography{$2}))
        {
          $bibliography{$2}{"name"} = $2;
          $bibliography{$2}{"cited"} = 1;
          $bibliography{$2}{"order"} = $i++;
        }
      }
      else
      {
        # was a %CITE{...}%
        if (exists $bibliography{$2})
        {
          if (not $bibliography{$2}{"cited"})
          {
            $bibliography{$2}{"cited"} = 1;
            $bibliography{$2}{"order"} = $i++; # citation order
          }
        }
      }
    }

    # delete non-cited entries:
    foreach $key (keys %bibliography)
    {
      if (not $bibliography{$key}{"cited"})
      {
        delete $bibliography{$key};
      }
    }

    #if needed, resort the cited entries for generating the numeration
    if ($order eq "alpha")
    {
      my $i = 1;
      foreach $key (sort bibliographyAlphaSort (keys %bibliography))
      {
        $bibliography{$key}{"order"} = $i++;
      }
    }
    
    $_[0] =~ s/%CITE(INLINE)?{([^}]*)}%/&handleCitation($2,%bibliography)/ge;
    $_[0] =~ s/%BIBLIOGRAPHY{([^}]*)}%/&generateBibliography($header, %bibliography)/ge;
}

1;
