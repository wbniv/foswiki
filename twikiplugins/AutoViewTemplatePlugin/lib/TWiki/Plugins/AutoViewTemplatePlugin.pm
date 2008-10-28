# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Oliver Krueger <ok@kontextwork.de>, KontextWork
# All Rights Reserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# This piece of software is licensed under the GPL.

package TWiki::Plugins::AutoViewTemplatePlugin;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $mode $override $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'ipo';
$SHORTDESCRIPTION = 'Sets VIEW_TEMPLATE according to the topic type';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoViewTemplatePlugin';


sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
    my $viewTemplate = "";

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get configuration
    $debug    = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug}    || 0;
    $mode     = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode}     || "exist";
    $override = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} || 0;    
	
    # get form-name
    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    my $form = $meta->get("FORM");
    my $formname = $$form{"name"};
    
    if ( $formname ne "" ) {
      TWiki::Func::writeDebug("- ${pluginName}: formfields detected ($formname)") if $debug;

      MODE: {
      	if ( $mode eq "section" ) {
          $viewTemplate = _getTemplateFromSectionInclude( $formname, $topic, $web );		
      	  last MODE;	
      	}
      	if ( $mode eq "exist" ) {
      	  $viewTemplate = _getTemplateFromTemplateExistence( $formname, $topic, $web );
      	  last MODE;	
      	}
      }
      
      # only set the view_template if there is anything to set
      if ( $viewTemplate ) {
        my $currentTemplate = TWiki::Func::getPreferencesValue("VIEW_TEMPLATE");
      
        if ( !$currentTemplate ) {
          TWiki::Func::writeDebug("- ${pluginName}: VIEW_TEMPLATE set to: $viewTemplate") if $debug;
          $TWiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION', { VIEW_TEMPLATE => $viewTemplate } );      	
        } else {
      	  if ( $override ) {
      	    TWiki::Func::writeDebug("- ${pluginName}: VIEW_TEMPLATE already set, overriding with: $viewTemplate") if $debug;
      	    $TWiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION', { VIEW_TEMPLATE => $viewTemplate } );
          } else {
      	    TWiki::Func::writeDebug("- ${pluginName}: VIEW_TEMPLATE not changed/set.") if $debug;
          }
        }      	
      }
    } 

    # Plugin correctly initialized
    return 1;
}

sub _getTemplateFromSectionInclude {
	my $formname = $_[0];
	my $topic    = $_[1];
	my $web      = $_[2];
	
    # add current webname, if formname is not fully qualified
    if ( $formname !~ m/\./ ) { $formname = $web . "." . $formname; };

    my ($formweb, $formtopic) = TWiki::Func::normalizeWebTopicName("", $formname);

    # SMELL: This can be done must faster, if the formdefinition topic is read directly
    my $viewTemplate = "%INCLUDE{ \"$formweb.$formtopic\" section=\"viewtemplate\"}%";
    $viewTemplate = TWiki::Func::expandCommonVariables( $viewTemplate, $topic, $web );
      
    # TODO: sanatize value
      
    return $viewTemplate;
}


# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate if it exists otherwise nothing
sub _getTemplateFromTemplateExistence {
	my $formName = $_[0];
	my $topic    = $_[1];
	my $web      = $_[2];
	
    # add current webname, if formname is not fully qualified
    if ( $formName !~ m/\./ ) { $formName = $web . "." . $formName; };
    my ($templateWeb, $templateTopic) = TWiki::Func::normalizeWebTopicName("", $formName);
    
    my $templateName = $formName;
    $templateName =~ s/Form$/ViewTemplate/;
    
    my $viewTemplate = TWiki::Func::topicExists( $templateWeb, $templateTopic ) ? $templateName : "";
    
    return $viewTemplate;
}

1;
