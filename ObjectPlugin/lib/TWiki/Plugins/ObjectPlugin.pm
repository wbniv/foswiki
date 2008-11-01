# ObjectPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) TWiki:Main.PiersGoodhew & TWikiContributors.

=pod

---+ package ObjectPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::ObjectPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $objectPluginDefHeight
  $objectPluginDefWidth $objectPluginDefUseEMBED $objectPluginDefController
  $objectPluginDefPlay $kMediaFileExtsPattern $htmlId);


# This should always be $Rev: 9813$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'ObjectPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    #TODO: these should be moved into Config.spec for performance.
    $objectPluginDefHeight =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_HEIGHT");
    $objectPluginDefWidth =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_WIDTH");
    $objectPluginDefController =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_CONTROLLER");
    $objectPluginDefPlay =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_PLAY");
    $objectPluginDefUseEMBED =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_USEEMBED");

    $objectPluginDefUseEMBED =
      ( $objectPluginDefUseEMBED eq "TRUE" );  #This one needs to be a perl bool

    # register the OBJECT function to handle %OBJECT{...}%
    TWiki::Func::registerTagHandler( 'OBJECT', \&_OBJECT );
    TWiki::Func::registerTagHandler( 'EMBED',  \&_EMBED );

    # Plugin correctly initialized
    return 1;
}

sub _EMBED {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    $params->{_EMBED} = 1; #signal that this should use MediaPlayer
    return _OBJECT( $session, $params, $theTopic, $theWeb );
}

# Our actual function
sub _OBJECT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $objectParams = " ";
    my $embedTags    = " ";
    if ($objectPluginDefUseEMBED) {
        $embedTags = "\t<EMBED "
          ; #you want a trailing space on pretty much everything that isn't an end tag
    }
    my $objectHeader = "<OBJECT ";
    my $objectFooter = "</OBJECT>";
    my $returnValue  = "";
    my ( $key, $value ) = ( 0, 0 );

    #	return $objectPluginDefUseEMBED;

#These three values are passed inside the <OBJECT> tag and not as <PARAM>s later ...
    my $height = $params->{height};
    my $width  = $params->{width};
    $params->{src} ||= $params->{_DEFAULT} || $params->{filename};

  #"src" is optional so we try the default param if "src" is ND
  #and if neither src, nor _DEFAULT are defined, try the EmbedPlugin filename=''

    #fall special values back to default if nd
    $height ||= $objectPluginDefHeight;
    $width  ||= $objectPluginDefWidth;

#copy the params into our own hash, then delete the values (if they're there) which are handled differently
#(if at all)
    my %localParams = %$params;
    delete $localParams{width}    if $localParams{width};
    delete $localParams{height}   if $localParams{height};
    delete $localParams{_DEFAULT} if $localParams{_DEFAULT};
    delete $localParams{_RAW}
      if $localParams{_RAW};  #don't know what it is or does, but it's there ...

    #detect file type ... this should be inside an if (don't be generic) block
    my ( $fileHeader, $fileExt ) = ( $localParams{src} =~ /(.*)\.+(.*$)/ );
    
    #EmbedPlugin hardcoded to MediaPlayer
    if ($params->{_EMBED} == 1) {
        $fileExt = 'wmv';
        delete $params->{_EMBED};
    }
    #assume youtube uses swf
    if ($localParams{src} =~ /youtube.com/) {
        $fileExt = 'swf';
    }

#We have a media-y file, fill out our various param synonyms from params/defaults
    $localParams{controller} ||= $objectPluginDefController;
    $localParams{showcontroller} =
      ( uc( $localParams{controller} ) eq "TRUE" ) ? 1 : 0;
    $localParams{autoplay} ||= $localParams{play} ||= $objectPluginDefPlay;
    $localParams{autostart} = ( uc( $localParams{play} ) eq "TRUE" ) ? 1 : 0;
    $localParams{movie} = $localParams{filename} = $localParams{src};
    
    #TODO: can I replace these with one tmpl file per format?
    # eg objectplugin_mov.tmpl? that way a skin could over-ride it with objectplugin_mov.jquery.tmpl
    # and thus we can
    TWiki::Func::loadTemplate ( 'objectplugin_'.$fileExt );
    my $format_objectHeader = TWiki::Func::expandTemplate('objectHeader_'.$fileExt);
    if ($format_objectHeader eq '') { #use generic
        TWiki::Func::loadTemplate ( 'objectplugin' );
        $objectHeader .= TWiki::Func::expandTemplate('objectHeader');
        $embedTags .= TWiki::Func::expandTemplate ( 'embedTag' );
        $localParams{data} = $localParams{src};
        $objectHeader .=  'data="'.$localParams{data}.'"';
        delete $localParams{src};
        delete $localParams{movie};
        delete $localParams{filename};
    } else {
        $objectHeader .= $format_objectHeader;
        if ($objectPluginDefUseEMBED) {
            $embedTags .= TWiki::Func::expandTemplate ( 'embedTag_'.$fileExt );
        }
        if ( $localParams{controller} ) {
            $height += TWiki::Func::expandTemplate('controlerHeight_'.$fileExt);
        }
    }

 #We can now parse the params out into the OBJECT and (maybe) the EMBED tags ...
    while ( ( $key, $value ) = each %localParams ) {
        $objectParams .=
          ( "\t<PARAM name=\"" . $key . "\" value=\"" . $value . "\" > \n" );
        if ($objectPluginDefUseEMBED) {
            $embedTags .= ( $key . "=\"" . $value . "\" " );
        }
    }

    #complete the OBJECT and (maybe) EMBED tags with the size param
    if ($objectPluginDefUseEMBED) {
        $embedTags .= "height=\"$height\" width=\"$width \"></embed>\n";
    }
    $objectHeader .= "height=\"$height\" width=\"$width\" id=\"ObjectPlugin".$htmlId++."\" \">\n";

    return $objectHeader . $objectParams . $embedTags . $objectFooter;
}
