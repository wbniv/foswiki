
package TWiki::Plugins::EmbedFlashPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
);

# This should always be $Rev: 16753 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 16753 $';
$RELEASE = '1.2.1';

$pluginName = 'EmbedFlashPlugin';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");
    TWiki::Func::registerTagHandler( 'EMBEDFLASH', \&_handleEmbedFlash );

    return 1;
}

sub _handleEmbedFlash {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $flashFileName = $params->{"filepath"} || $params->{_DEFAULT};
    my $movieId = $params->{"id"};
    my $flashId;
    if ( !$movieId ) {
        $flashFileName =~ m/^((.*?)\/)*(.*).swf$/;
        $flashId = $3;
    }
    else {
        $flashId = $movieId;
    }
    $flashId .= '.swf';
    my $flashWidth      = $params->{"width"}      || "100%";
    my $flashHeight     = $params->{"height"}     || "100%";
    my $flashBackground = $params->{"background"} || $params->{"bgcolor"} || "";
    my $flashVersion    = $params->{"version"}    || "9";
    my $flashQuality    = $params->{"quality"}    || "high";
    my $flashAlign      = $params->{"align"}      || "";
    my $flashSAlign     = $params->{"salign"}     || "";
    my $flashScale      = $params->{"scale"}      || "";
    my $flashWMode      = $params->{"wmode"}      || "";
    my $flashLoop       = $params->{"loop"}       || "true";
    my $flashPlay       = $params->{"play"}       || "true";
    my $flashAllowContextMenu  = $params->{"menu"}              || "true";
    my $flashAllowFullScreen   = $params->{"fullscreen"}        || "false";
    my $flashAllowScriptAccess = $params->{"allowscriptaccess"} || "sameDomain";
    my $flashBase          = $params->{"base"}          || "%ATTACHURL%/";
    my $flashSwliveconnect = $params->{"swliveconnect"} || "";
    my $flashVars          = $params->{"flashvars"}     || undef;

    $objectEmbed = "";
    my $itemSeparator = " ";
    $objectEmbed .= "<object";
    $objectEmbed .=
      $itemSeparator . 'classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"';
    $objectEmbed .=
        $itemSeparator
      . 'codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version='
      . $flashVersion
      . ',0,0,0"';
    $objectEmbed .= $itemSeparator . 'width="' . $flashWidth . '"';
    $objectEmbed .= $itemSeparator . 'height="' . $flashHeight . '"';
    $objectEmbed .= $itemSeparator . 'id="' . $flashId . '"';
    $objectEmbed .= $itemSeparator . 'align="' . $flashAlign . '"';
    $objectEmbed .= '>';
    $objectEmbed .=
        $itemSeparator
      . '<param name="allowScriptAccess" value="'
      . $flashAllowScriptAccess . '" />';
    $objectEmbed .=
        $itemSeparator
      . '<param name="allowFullScreen" value="'
      . $flashAllowFullScreen . '" />';
    $objectEmbed .=
      $itemSeparator . '<param name="movie" value="' . $flashId . '" />';
    $objectEmbed .=
      $itemSeparator . '<param name="FlashVars" value="' . $flashVars . '" />'
      if defined $flashVars;
    $objectEmbed .=
      $itemSeparator . '<param name="quality" value="' . $flashQuality . '" />';
    $objectEmbed .=
        $itemSeparator
      . '<param name="bgcolor" value="'
      . $flashBackground . '" />';
    $objectEmbed .=
      $itemSeparator . '<param name="base" value="' . $flashBase . '" />';
    $objectEmbed .=
        $itemSeparator
      . '<param name="swliveconnect" value="'
      . $flashSwliveconnect . '" />';
    $objectEmbed .= $itemSeparator . '<embed';
    $objectEmbed .= $itemSeparator . 'src="' . $flashFileName . '"';
    $objectEmbed .= $itemSeparator . 'FlashVars="' . $flashVars . '"'
      if defined $flashVars;
    $objectEmbed .= $itemSeparator . 'quality="' . $flashQuality . '"';
    $objectEmbed .= $itemSeparator . 'bgcolor="' . $flashBackground . '"';
    $objectEmbed .= $itemSeparator . 'width="' . $flashWidth . '"';
    $objectEmbed .= $itemSeparator . 'height="' . $flashHeight . '"';
    $objectEmbed .= $itemSeparator . 'name="' . $flashId . '"';
    $objectEmbed .= $itemSeparator . 'align="' . $flashAlign . '"';
    $objectEmbed .= $itemSeparator . 'base="' . $flashBase . '"';
    $objectEmbed .=
      $itemSeparator . 'swliveconnect="' . $flashSwliveconnect . '"';
    $objectEmbed .=
      $itemSeparator . 'allowScriptAccess="' . $flashAllowScriptAccess . '"';
    $objectEmbed .=
      $itemSeparator . 'allowFullScreen="' . $flashAllowFullScreen . '"';
    $objectEmbed .= $itemSeparator . 'type="application/x-shockwave-flash"';
    $objectEmbed .= $itemSeparator
      . 'pluginspage="http://www.macromedia.com/go/getflashplayer"';
    $objectEmbed .= $itemSeparator . '/>';
    $objectEmbed .= '</object>';

    my $noScriptCode = "<literal><noscript>$objectEmbed</noscript></literal>";
    my $scriptCode =
      "<script language=\"javascript\">document.write('$objectEmbed')</script>";

    return $scriptCode . $noScriptCode;
}

1;
