# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package PloticusPlugin

This is an empty TWiki plugin. It is a fully defined plugin, but is
disabled by default in a TWiki installation. Use it as a template
for your own plugins; see %SYSTEMWEB%.Plugins for details.

__NOTE:__ To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.


For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin (or you can put __END__ on a line of it's own and move dead
code below that line; Perl ignores anything after __END__).

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
Check the warning log file (defined by $TWiki::cfg{WarningFileName}) for
errors.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in [[%SYSTEMWEB%.Plugins#FAILEDPLUGINS]]. See [[%SYSTEMWEB%.Plugins]] 
for information on guarding deprecated handlers that are defined for 
compatibility with older TWiki versions.

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::PloticusPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 8354$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 1.0$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';



# Name of this Plugin, only used in this module
$pluginName = 'PloticusPlugin';


=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle tags that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut


sub initPlugin {
    #TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    my( $topic, $web, $user, $installWeb ) = @_;
    $debug = TWiki::Func::getPreferencesValue( 'PLOTICUSPLUGIN_DEBUG' );
    $debug = 1;
    TWiki::Func::writeDebug( "Initialising PloticusPlugin...." ) if $debug;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # register the handlePloticusTag function to handle %PLOTICUSPLOT{...}% tag
    TWiki::Func::registerTagHandler( 'PLOTICUSPLOT', \&handlePloticusTag );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('Ploticus', \&restPloticus);

    # Plugin correctly initialized
    return 1;
}


sub handlePloticusTag {
    my($session, $params, $topic, $web) = @_;
    # $session  - not used.
    # $params=  - _DEFAULT is the name of the plot
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: rendered text for the plugin

    TWiki::Func::writeDebug( "PloticusPlugin::handlePloticusTag for $web - $topic Name=$params->{_DEFAULT}" ) if $debug;
    my $plotName = $params->{_DEFAULT};
    unless ($plotName) { return showError('Plot must have a name.'); };
    my $query = TWiki::Func::getCgiQuery();
    my $action = $query->param( 'ploticusPlotAction');
    unless ($action) { return showPlot($web, $topic, $plotName); };
    my $queryTarget = $query->param( 'ploticusPlotName');
    if ($action eq 'edit' and $queryTarget eq $plotName) { return editPlotSettings($web, $topic, $plotName); };
    if ($action eq 'save' and $queryTarget eq $plotName) { return savePlotSettings($web, $topic, $plotName, $query->param( 'ploticusPlotSettingsText')); };
    return showPlot($web, $topic, $plotName); 
}

sub showError{
    my $error = shift;
    TWiki::Func::writeDebug( "PloticusPlugin showError" ) if $debug;
    return "Error: $error\n";
}

sub showPlot{
    my ($web, $topic, $name) = @_;
    TWiki::Func::writeDebug( "PloticusPlugin::showPlot  - showPlot for $web, $topic, $name" ) if $debug;
    require TWiki::Plugins::PloticusPlugin::Plot;
    my $plot = TWiki::Plugins::PloticusPlugin::Plot->new($web, $topic, $name);
    return $plot->render();
}

sub editPlotSettings{
    my ($web, $topic, $name) = @_;
    TWiki::Func::writeDebug( "PloticusPlugin::editPlotSettings for $web, $topic, $name" ) if $debug;
    require TWiki::Plugins::PloticusPlugin::PlotSettings;
    my $settings = TWiki::Plugins::PloticusPlugin::PlotSettings->fromFile($web, $topic, $name);
    return $settings->render();
}

sub savePlotSettings{
    my ($web, $topic, $name, $text) = @_;
    TWiki::Func::writeDebug( "PloticusPlugin::savePlotSettings $web, $topic, $name, $text" ) if $debug;
    require TWiki::Plugins::PloticusPlugin::PlotSettings;
    TWiki::Func::writeDebug( "PloticusPlugin::savePlotSettings ----------------------------------------------------" ) if $debug;
    TWiki::Plugins::PloticusPlugin::PlotSettings::writeFile($web, $topic, $name, $text);
    TWiki::Func::writeDebug( "PloticusPlugin::savePlotSettings OOOOO----------------------------------------------------" ) if $debug;
    TWiki::Func::redirectCgiQuery( {}, TWiki::Func::getScriptUrl( $web, $topic, "view" ) . "\#ploticusplot$name");
}


=pod

---++ earlyInitPlugin()

May be used by a plugin that requires early initialization. This handler
is called before any other handler.

If it returns a non-null error string, the plugin will be disabled.

=cut

sub DISABLE_earlyInitPlugin {
    return undef;
}

=pod

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username, for example based on cookies.

Return the user name, or =guest= if not logged in.

This handler is called very early, immediately after =earlyInitPlugin=.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_initializeUserHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $loginName, $url, $pathInfo ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ registrationHandler($web, $wikiName, $loginName )
   * =$web= - the name of the web in the current CGI query
   * =$wikiName= - users wiki name
   * =$loginName= - users login name

Called when a new user registers with this TWiki.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_registrationHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $web, $wikiName, $loginName ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ commonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the code that expands %TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Plugins that want to implement their own %TAGS% with non-trivial
additional syntax should implement this function. Internal TWiki
tags (and any tags declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %TAGS% are expanded.

For tags with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other HTML such as &lt;pre> blocks is
still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub DISABLE_commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

=pod

---++ beforeCommonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called before TWiki does any expansion of it's own
internal tags. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub DISABLE_beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterCommonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is after TWiki has completed expansion of %TAGS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub DISABLE_afterCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Handler called immediately before TWiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are inserted into the text inside &lt;!--!marker!--&gt; characters so the text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e. it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_preRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

__NOTE__: This handler is called once for each rendered block of text i.e. it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
}

=pod

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

__NOTE__: meta-data may be embedded in the text passed to this handler (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterEditHandler($text, $topic, $web )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the preview script just before presenting the text.
It is called once when the =preview= script is run.

__NOTE:__ this handler is _not_ called unless the text is previewed.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_afterEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.020'

=cut

sub DISABLE_afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called once when an attachment is uploaded.

The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's Web.<nop>WikiName

__Since:__ TWiki::Plugins::VERSION = '1.023'

=cut

sub DISABLE_beforeAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterAttachmentSaveHandler(\%attrHash, $topic, $web, $error )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string generated during the save process
This handler is called just after the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's Web.<nop>WikiName

__Since:__ TWiki::Plugins::VERSION = '1.023'

=cut

sub DISABLE_afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ mergeHandler( $diff, $old, $new, \%info ) -> $text
Try to resolve a difference encountered during merge. The =differences= array is an array of hash references, where each hash contains the following fields:
   * =$diff= => one of the characters '+', '-', 'c' or ' '.
      * '+' - =new= contains text inserted in the new version
      * '-' - =old= contains text deleted from the old version
      * 'c' - =old= contains text from the old version, and =new= text from the version being saved
      * ' ' - =new= contains text common to both versions, or the change only involved whitespace
   * =$old= => text from version currently saved
   * =$new= => text from version being saved
   * =\%info= is a reference to the form field description { name, title, type, size, value, tooltip, attributes, referenced }. It must _not_ be wrtten to. This parameter will be undef when merging the body text of the topic.

Plugins should try to resolve differences and return the merged text. For example, a radio button field where we have ={ diff=>'c', old=>'Leafy', new=>'Barky' }= might be resolved as ='Treelike'=. If the plugin cannot resolve a difference it should return undef.

The merge handler will be called several times during a save; once for each difference that needs resolution.

If any merges are left unresolved after all plugins have been given a chance to intercede, the following algorithm is used to decide how to merge the data:
   1 =new= is taken for all =radio=, =checkbox= and =select= fields to resolve 'c' conflicts
   1 '+' and '-' text is always included in the the body text and text fields
   1 <del>conflict</del> <ins>markers</ins> are used to mark 'c' merges in text fields

The merge handler is called whenever a topic is saved, and a merge is required to resolve concurrent edits on a topic.

=cut

sub DISABLE_mergeHandler {
}

=pod

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =TWiki::Func::addToHEAD= method.

__Since:__ TWiki::Plugins::VERSION 1.026

=cut

sub DISABLE_modifyHeaderHandler {
    my ( $headers, $query ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::modifyHeaderHandler()" ) if $debug;
}

=pod

---++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace TWiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_redirectCgiQueryHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $query, $url ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;
}

=pod

---++ renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html

This handler is called before built-in types are considered. It generates the HTML text rendering this form field, or false, if the rendering should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if any. May be a scalar (one legal value) or a ref to an array (several legal values)
Return HTML text that renders this field. If false, form rendering continues by considering the built-in types.

=cut

sub DISABLE_renderFormFieldForEditHandler {
}


=pod


---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

=cut

sub restPloticus {
   #my ($session) = @_;
   return "This is an example of a REST invocation\n\n";
}

1;
