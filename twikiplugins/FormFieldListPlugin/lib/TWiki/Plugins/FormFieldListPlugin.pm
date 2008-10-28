# FormFieldListPlugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Rafael Alvarez, soronthar@flashmail.com
# Copyright (C) 2004 Bernd Raichle, bernd.raichle@gmx.de
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
# FormFieldListPlugin
#
# The plugin can be used to format a sequence of FORMFIELD values.
#
# Syntax:
#   %FORMFIELDLIST{ "comma-separated sequence of form field names"
#                    topic="..."     (optional: default is %TOPIC%)
#                    alttext="..."   (optional: default '')
#                    default="..."   (optional: default '')
#                    separator="..." (optional: default is $n)
#                    format="..."    (optional: default is $title=$value)
#                 }%
#
#   This text string expression must appear on one line.
#
#   =format= will be inserted for all existing fields with
#   non-empty values.
#   =alttext= will be inserted for all existing fields with
#   empty values.
#   =default= will be inserted for all non-existing fields.
#   =separator= will be inserted between all non-empty output
#   records.
#
#   Inside =format= the variable =$value= will expand to the
#   field value.
#   Inside =format= and =default= the variables =$name= and
#   =$title= will expand to the field name (without spaces)
#   and the field title (field name as specified in the form).
#   Inside =alttext= the variables =$name= and
#   =$title= will both expand to the given but non-existing
#   form field name.
#
#   The variable $n will expand to newline in the parameters
#   =alttext=, =default=, =separator=, and =format=.
#


# =========================
package TWiki::Plugins::FormFieldListPlugin;

# =========================
use strict;

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
	$debug
    );

# This should always be $Rev: 14008 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14008 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'FormFieldListPlugin';   # Name of this Plugin


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        &TWiki::Func::writeWarning( "Version mismatch between ${pluginName} and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPluginPreferencesValue( "DEBUG" );

    TWiki::Func::registerTagHandler('FORMFIELDLIST',\&getFormFieldList);
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}



=pod

---++ sub getFormFieldList ( $web, $topic, $args )

+Returns the expansion of a %FORMFIELDLIST{}% tag.

=cut

sub getFormFieldList
{
    my ($session, $params, $topic, $web) = @_;


    my $formFieldList = $params->{_DEFAULT};
    my $separator = $params->{'separator'} || "\n";
    my $format=$params->{'format'} || '$value';
    my $formTopic=$params->{'topic'} || $topic;
    my $default=$params->{'default'} || '';
    my $alttext=$params->{'alttext'} || '';

    my $text='';
    foreach my $formField ( split( /\s*,\s*/, $formFieldList) ) {
       $params->{_DEFAULT}=$formField;
       $text .= '%FORMFIELD{"'.$formField.'" '
               .'format="'.$format.'" '
	       .'topic="'.$formTopic.'" '
               .'default="'.$default.'" '
               .'alttext="'.$alttext.'" '
               .'}%';

       $text.= $separator;
    }

    return $text;
}

1;
