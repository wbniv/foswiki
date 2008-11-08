#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2005 Alex alex-kane@usres.sourceforge.com
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
# This is a CategoryPlugin TWiki plugin. Use it as a template
# for your own plugins; see Plugins.CategoryPlugin for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::CategoryPlugin; 	# change the package name!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug $categoryTemplate
        $globalCategoriesWeb $categoryImgUrl $categoryHeader $categorySearch 
    );

# This should always be $Rev: 15561 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15561 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub  initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::CategoryPlugin::initPlugin is OK" ) if $debug;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between CategoryPlugin and Plugins.pm" );
        return 0;
    }

    $categoryTemplate= &TWiki::Func::getPreferencesValue( "CATEGORY_TEMPLATE" ) || &TWiki::Func::getPreferencesValue( "CATEGORYPLUGIN_CATEGORY_TEMPLATE" ) || "%SYSTEMWEB%.CategoryTemplate";

    # web where global categories topics are stored
    $globalCategoriesWeb = &TWiki::Func::getPreferencesValue( "GLOBAL_CATEGORIES_WEB" ) || &TWiki::Func::getPreferencesValue( "CATEGORYPLUGIN_GLOBAL_CATEGORIES_WEB" ) || "%SYSTEMWEB%";

    # CATEGORY_SEARCH
    $categorySearch = &TWiki::Func::getPreferencesValue( "GLOBAL_CATEGORIES_WEB" ) || &TWiki::Func::getPreferencesValue( "CATEGORYPLUGIN_GLOBAL_CATEGORIES_WEB" ) || "%SEARCH{\".*Category$\" scope=\"topic\" regex=\"on\" order=\"topic\" web=\"%CATEGORY_WEBS%\" nosearch=\"on\" nosummary=\"on\" }%";

    $categoryImgUrl = &TWiki::Func::getPreferencesValue( "CATEGORYPLUGIN_CATEGORYIMGURL" )  || "%M%";
    $categoryHeader = &TWiki::Func::getPreferencesValue( "CATEGORYPLUGIN_HEADER" )  || "[[Categories]]: |";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "CATEGORYPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::CategoryPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- CategoryPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/%CATEGORY\{(.+)\}%/&CategoryShowLinks($1)/geo;
    $_[0] =~ s/%CATEGORY\{\}%/&CategoryShowLinks($1)/geo;
    $_[0] =~ s/%CATEGORY_TEMPLATE%/&CategoryTemplate/geo;
    $_[0] =~ s/%GLOBAL_CATEGORIES_WEB%/&GlobalCategoriesWeb/geo;
    $_[0] =~ s/%CATEGORY_SEARCH%/&CategorySearch/geo;

#    $_[0] =~ s/%PATENTAPP\{([0-9]+)\}%/&PatentApplicationShowLink($1)/geo;
#    $_[0] =~ s/%BUGLIST\{(.+)\}%/&BugzillaShowMilestoneBugList($1)/geo;
#    $_[0] =~ s/%MYBUGS\{(.+)\}%/&BugzillaShowMyBugList($1)/geo;
}

sub CategoryShowLinks {
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks(ENTERED)" ) if $debug;
    my ($cats) = @_;
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \@cats = $cats)" ) if $debug;

    if (!$cats) { return ""; }

    my (@categories) = split (/[ |,]/, $cats);
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \@categories = @categories)\nprinting:" ) if $debug;

    my ($categoryLinks) = "";

    foreach $cat (@categories) {
        if (!$cat) {
            next;
        }
        &TWiki::Func::writeDebug( "\t\$cat = $cat)\n" ) if $debug;
        $categoryLinks = "$categoryLinks [[$cat]] |";
    }

    $categoryLinks = "$categoryHeader$categoryLinks";

    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \$categoryLinks = $categoryLinks)" ) if $debug;

    # return "$categoryImgUrl$categoryLinks\n---";
    return "$categoryLinks\n---";
}

sub CategoryTemplate {
    return $categoryTemplate;
}

sub GlobalCategoriesWeb {
    return $globalCategoriesWeb;
}

sub CategorySearch {
    return "$categorySearch";
}

1;
