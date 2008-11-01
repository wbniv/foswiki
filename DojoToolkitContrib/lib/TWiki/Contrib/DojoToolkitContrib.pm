package TWiki::Contrib::DojoToolkitContrib;
use vars qw( $VERSION $pluginName );
$VERSION = '$Rev$';
$pluginName = 'DojoToolkitContrib';

use strict;
use TWiki::Func;


#not sure its going to be useful, but....
#this would allow multiple contribs/plugins to require the same components,
#without them gong into the head more than once.
#TODO: have to implement my own addToHEAD so that the ordering works :(
#   and that will have to be done in a Plugin, to hook into the completePageHandler
sub requireJS {
    my $module = shift;
    
    #TODO: ( $name, $skin, $web ) paramters?
    my $javascript = TWiki::Func::loadTemplate('javascript.dojo');
    TWiki::Func::addToHEAD('AA'.$pluginName.'.javascript.dojo', $javascript);
    
    my $output = "<script type=\"text/javascript\">dojo.require(\"$module\");</script>";
    TWiki::Func::addToHEAD('AB'.$pluginName.'.'.$module, $output);
}


1;
