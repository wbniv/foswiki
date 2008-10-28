#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# for your own plugins; see TWiki.TWikiPlugins for details.
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
package TWiki::Plugins::BeautifierPlugin; 	# change the package name!!!
use Beautifier::Core;
use Output::HTML;

# =========================

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug %langs
    );

# This should always be $Rev: 14774 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14774 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    %langs = ();

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between BeautifierPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "BEAUTIFIERPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::BeautifierPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # &TWiki::Func::writeDebug( "- BeautifierPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # Find code tag and beautify
    $_[0] =~ s/%CODE{(.*?)}%(.*?)%ENDCODE%/&handleCode($1, $2)/gseo;
}

# =========================

sub handleCode
{
    my ( $args, $codeFragment ) = @_;

    TWiki::Func::addToHEAD( BEAUTIFIERPLUGIN_CODEFRAGMENT_CSS => '<link rel="stylesheet" href="%PUBURL%/%SYSTEMWEB%/BeautifierPlugin/style.css" type="text/css" media="all" />' );

    my $lang = TWiki::Func::extractNameValuePair( $args );	# || default language (eg, TWiki::Func::getPreferencesValue(uc 'BEAUTIFIERPLUGIN_LANGUAGE' ) 
    unless ($langs->{$lang})
    {
        local $SIG{__DIE__};
        eval "use HFile::HFile_$lang";
        if ($@)
        {
            return qq{<b>BeautifierPlugin Error: Unable to handle "$lang" language.</b>}
		. _formatBeautifierOutput( $codeFragment );
        }
        my $hfile = eval "new HFile::HFile_$lang";
        $langs->{$lang} = new Beautifier::Core($hfile, new Output::HTML);
    }
    return _formatBeautifierOutput( $langs->{$lang}->highlight_text( $codeFragment ) );
}

# =========================

sub _formatBeautifierOutput {
    return '<div class="BeautifierPlugin"><div class="fragment"><pre>' . shift() . '</pre></div></div>';
}

# =========================
1;
