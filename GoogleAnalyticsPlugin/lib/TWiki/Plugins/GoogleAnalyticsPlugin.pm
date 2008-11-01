package TWiki::Plugins::GoogleAnalyticsPlugin;

use strict;

use vars qw( $VERSION $RELEASE $pluginName $debug $initialised $googleSiteKey );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'GoogleAnalyticsPlugin';

#there is no need to document this.
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
    
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
    # Get plugin preferences, variables defined by:
    #   * Set GOOGLESITEKEY = ...
	$googleSiteKey = TWiki::Func::getPluginPreferencesValue( "GOOGLESITEKEY" );

	_addToHead();
    return 1;
}

sub _addToHead {

    my $header = '<!-- Google Analytics script -->
<script src="http://www.google-analytics.com/urchin.js" type="text/javascript"></script>
<script type="text/javascript">
// <![CDATA[
function sendStats(inPageId) {
	var pageId = (inPageId != undefined) ? inPageId : "";
	urchinTracker(pageId);
}
_uacct = "'.$googleSiteKey.'";
sendStats();
// ]]>
</script>
';
	TWiki::Func::addToHEAD('GOOGLEANALYTICSPLUGIN',$header)
}

1;
