# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=begin TML

---+ package Foswiki::Plugins::TWikiCompatibilityPlugin


=cut


package Foswiki::Plugins::TWikiCompatibilityPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;    # The plugins API
require Foswiki::Plugins; # For the API version
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );
$VERSION = '$Rev$';
$RELEASE = 'Foswiki-1.0';
$SHORTDESCRIPTION = 'add TWiki personality to Foswiki';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'TWikiCompatibilityPlugin';

=begin TML

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
    return 1;
}

=begin TML

---++ earlyInitPlugin()

If the TWiki web does not exist, change the request to the %SYSTEMWEB%

This may not be enough for Plugins that do have in topic preferences.

=cut

sub earlyInitPlugin {

    my $session = $Foswiki::Plugins::SESSION;
    if (($session->{webName} eq 'TWiki') &&
            (!Foswiki::Func::topicExists($session->{webName}, $session->{topicName}))) {
        my $TWikiWebTopicNameConversion = $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TWikiWebTopicNameConversion};
        $session->{webName} = $Foswiki::cfg{SystemWebName};
        if (defined($TWikiWebTopicNameConversion->{$session->{topicName}})) {
            $session->{topicName} =
                    $TWikiWebTopicNameConversion->{$session->{topicName}};
#print STDERR "converted to $session->{topicName}";
        }
    }
    my $MainWebTopicNameConversion = $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{MainWebTopicNameConversion};
    if (($session->{webName} eq 'Main') &&
            (defined($MainWebTopicNameConversion->{$session->{topicName}}))) {
        $session->{topicName} =
            $MainWebTopicNameConversion->{$session->{topicName}};
#print STDERR "converted to $session->{topicName}";
    }

    #Map TWIKIWEB to SYSTEMWEB and MAINWEB to USERSWEB
    #TODO: should we test for existance and other things?
    Foswiki::Func::setPreferencesValue('TWIKIWEB', 'TWiki');
    Foswiki::Func::setPreferencesValue('MAINWEB', '%USERSWEB%');

    # Load TWiki::Func and TWiki::Plugins, for badly written plugins
    # which rely on them being there without using them first
    use TWiki::Func;
    use TWiki::Plugins;

    return;
}

1;
