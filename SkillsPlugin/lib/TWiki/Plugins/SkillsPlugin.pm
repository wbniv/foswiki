# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
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

package TWiki::Plugins::SkillsPlugin;
use strict;
use vars qw(    $VERSION
                $RELEASE
                $NO_PREFS_IN_TOPIC
                $SHORTDESCRIPTION
                $pluginName

                $doneHeader

                $globTopic
                $globWeb

                $allowedit

                $message
                $addeditMessage
                $searchResults
        );

# MESSAGES: Have to be global, or get lost in commonTagsHandler
# $message - added to the admin topic to confirm changes to categories/skills
# $addeditMessage - added to the bottom of EDITSKILLS form to confirm changes
# searchResults - message added to show how many matches in a search

# Plugin Variables
$VERSION = '$Rev: 9813$';
$RELEASE = 'Dakar';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Allows users to list their skills, which can then be searched';
$pluginName = 'SkillsPlugin';

# =========================
sub initPlugin {
    ( $globTopic, $globWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        _Warn( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $message = '';
    $searchResults = '';
    $addeditMessage = '';
    $doneHeader = 0;

    # Register tag %SKILLS%
    TWiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );

    _Debug("initPlugin( $globWeb.$globTopic ) is OK");

    return 1;
}

sub _handleTag {
    require TWiki::Plugins::SkillsPlugin::Tag;

    my $out = '';

    my $action = $_[1]->{action} || $_[1]->{_DEFAULT} || return;

    my $start = "<noautolink>\n";
    my $end = "\n</noautolink>";

    for ($action){
        /user/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_userSkills($_[1]) . $end, last;
        /browse/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_browseSkills($_[1]) . $end, last;
        /edit/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_editSkills($_[1]) . $end, last;
        /showskill/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_showSkills($_[1]) . $end, last;
        /showcat/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_showCategories($_[1]) . $end, last;
        /search/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_searchForm($_[1]) . $end, last;
    }

    _addCssStyle();

    $allowedit = 0;

    return $out;

}

# =========================
sub commonTagsHandler {
        
    my $query = TWiki::Func::getCgiQuery();
    return unless ($query);

# user add/edit a skill
    if(defined $query->{'editskills'}){
        # so we only execute once (performance)
        $query->{'editskills'} = undef;

        require TWiki::Plugins::SkillsPlugin::Query;

        $addeditMessage = TWiki::Plugins::SkillsPlugin::Query::_addEditSkill(
            $query->{'category'}[0],
            $query->{'skill'}[0],
            $query->{'rating'}[0],
            $query->{'comment'}[0]
        );
     } 

    # add/edit message
    $_[0] =~ s/%ADDEDITMESSAGE%/$addeditMessage/;

# search skills
    if(defined $query->{'searchskills'}){
        $query->{'searchskills'} = undef;

        require TWiki::Plugins::SkillsPlugin::Query;
        $searchResults = TWiki::Plugins::SkillsPlugin::Query::_searchSkills(
            $query->{'category'}[0],
            $query->{'skill'}[0],
            $query->{'ratingFrom'}[0],
            $query->{'ratingTo'}[0],
            $query->{'topicsearch'}[0]
        );

    }

    # search results
    if ($_[0] =~ m/%SKILLSSEARCHRESULTS%/){

        TWiki::Func::addToHEAD('SKILLSPLUGIN_SEARCHSKILLS_JSCRIPT',_skillJScript('searchskills'));

        $_[0] =~ s/%SKILLSSEARCHRESULTS%/$searchResults/;
    }

# manage categories/skills
# If there is a preference in Main.TWikiPreferences, only people listed and admins can add categories/skills
    unless ( isAllowed() ) {
        $_[0] =~ s!%ADDSKILLSMESSAGE%!<div class="skillNotification">
                                      %ICON{"warning"}% You do not have permission to add skills/categories.
                                      Contact %WIKIWEBMASTER% for more information.
                                      </div>!;

        $allowedit = 1;
    }

# add new category
    if(defined $query->{'createcategory'}){
        $query->{'createcategory'} = undef;
        return if $allowedit;

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_createCategory($query->{'category'}[0]);

# add new skill
    } elsif(defined $query->{'createskill'}){
        $query->{'createskill'} = undef;
        return if $allowedit;

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_createSkill(
            $query->{'newskill'}[0],
            $query->{'incategory'}[0]
        );
    } 

    if($message){
        $_[0] =~ s!%ADDSKILLSMESSAGE%!<div class="skillNotification">
                                      $message
                                      </div>!;
    } else {
        $_[0] =~ s/%ADDSKILLSMESSAGE%//;
    }
        
# Only admins can rename and delete categories/skills
# this is because we need to edit user topics, to get the meta data
    #unless($user->isAdmin()){
    unless( isAdmin() ){
        $_[0] =~ s!%MANAGESKILLSMESSAGE%!<div class="skillNotification">
                                         %ICON{"warning"}% You need to be an administrator to manage to skills. 
                                         Contact %WIKIWEBMASTER% for more information.
                                         </div>!;
        return;
    }
        
# rename category
    if(defined $query->{'renamecategory'}){
        $query->{'renamecategory'} = undef;

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_renameCategory(
            $query->{'oldcategory'}[0],
            $query->{'newcategory'}[0]
        );

# delete category
    } elsif(defined $query->{'deletecategory'}){
        $query->{'deletecategory'} = undef;

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_deleteCategory($query->{'oldcategory'}[0]);
                                
# rename skill 
    } elsif(defined $query->{'renameskill'}){
        $query->{'renameskill'} = undef;

        my ($cat, $oldskill) = split('\|', $query->{'oldskill'}[0]);

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_renameSkill(
            $cat,
            $oldskill,
            $query->{'newskill'}[0]
        );

# move skill 
    } elsif(defined $query->{'moveskill'}){
        $query->{'moveskill'} = undef;

        my ($oldcat, $skill) = split('\|', $query->{'movefrom'}[0]);
        my $newcat = $query->{'moveto'}[0];

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_moveSkill(
            $skill,
            $oldcat,
            $newcat
        );

# delete skill
    } elsif(defined $query->{'deleteskill'}){
       $query->{'deleteskill'} = undef;

        my ($cat, $skill) = split('\|', $query->{'oldskill'}[0]);

        require TWiki::Plugins::SkillsPlugin::Query;
        $message = TWiki::Plugins::SkillsPlugin::Query::_deleteSkill(
           $cat,
            $skill
        );
    }
        
    # category/skill message
    if($message){
        $_[0] =~ s!%MANAGESKILLSMESSAGE%!<div class="skillNotification">$message</div>!;
    } else {
        $_[0] =~ s/%MANAGESKILLSMESSAGE%//;
    }

}

# =========================
# Adds the css styles to the header
sub _addCssStyle {
        
    return if $doneHeader;
    $doneHeader = 1;
        
    my $defaultStyle = TWiki::Func::getPubUrlPath() . '/' . # /pub/
                       TWiki::Func::getTwikiWebname() . '/' . # TWiki/
                       $pluginName . '/' . # SkillsPlugin/
                       'style.css';

    my $styleUrl = TWiki::Func::getPreferencesValue("SKILLS_STYLEURL") || $defaultStyle;
    my $header = "<style type='text/css' media='all'>\@import url('$styleUrl');</style>";

    TWiki::Func::addToHEAD('SKILLSPLUGIN_CSS',$header);
}

# javascript used in edit skills form and search skills form
sub _skillJScript {
    require TWiki::Plugins::SkillsPlugin::Func;

    # which form
    my $form = shift;

    my $JScriptOptions = 'options[0] = new Option("Choose a skill...", "0", true);';
    my $JScriptRatings = '';
    my $JScriptComments = '';

    my $allSkills = ();
    $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();
        
    # creates a javascript if statement, which will define which skills
    # to display depending on the category selected
    foreach my $cat (sort keys %$allSkills){
        $JScriptOptions .= "\t\tif (SelValue == '$cat'){\n";
        @{ $allSkills->{$cat} } = sort @{ $allSkills->{$cat} };
        for my $skill ( 0 .. $#{ $allSkills->{$cat} } ) {
            $JScriptOptions .= "\t\t\toptions[$skill+1] = new Option('$allSkills->{$cat}->[$skill]', '$allSkills->{$cat}->[$skill]');\n";
        }
            $JScriptOptions .= "\t\t}\n";
    }

    my $user =  TWiki::Func::getWikiName();
    my $skills = TWiki::Plugins::SkillsPlugin::Func::_getUserSkills($user);
    foreach my $key (@$skills) {
        # ratings
        $JScriptRatings .= "\t\trating['$key->{'name'}'] = $key->{'rating'};\n";
        # comments
        $JScriptComments .= "\t\tcomment['$key->{'name'}'] = '$key->{'comment'}';\n"
            if $key->{'comment'};
    }

    my $outJScript = <<"EOT";
<script type="text/javascript">
// Populates the skills drop down menu
function setSkills(dropdown)
{
        var myindex  = dropdown.selectedIndex
        var SelValue = dropdown.options[myindex].value

        with (document.$form.skill){
                document.$form.skill.options.length = 0;
                if(document.$form.rating){
                        document.$form.rating[4].checked = true;
                        document.$form.comment.value = "";
                        hideCancelComment();
                }
$JScriptOptions
        }

}
// Selects the rating radio button if the user is editing
// an existing skill
function setRating(dropdown)
{
        var myindex  = dropdown.selectedIndex
        var SelValue = dropdown.options[myindex].value
        var rating = new Object;
        var comment = new Object;
        
$JScriptRatings

$JScriptComments

        if (rating[SelValue]){
                document.$form.rating[rating[SelValue]-1].checked = true;
        } else {
                document.$form.rating[4].checked = true;
        }

        if (comment[SelValue]){
                document.$form.comment.value = comment[SelValue];
                showCancelComment();
        } else {
                document.$form.comment.value = "";
                hideCancelComment();
        }
}

function hideCancelComment() {
        var el = document.getElementById('clearComment');
        el.style.display='none';
}

function showCancelComment() {
        var el = document.getElementById('clearComment');
        el.style.display='';
}

function clearText(el) {
        el.value = "";
        hideCancelComment();
}
</script>
EOT

    return $outJScript;

}

# Javascript for twisty effect (using tbody)
sub _addJScriptTbody {

    my $docpath = _getDocPath();
    
    my $jScript = <<"EOT";
<script type="text/javascript">
function hideShow(id){
        var body = document.getElementById(id);
        if (body) {
                if (body.style.display == 'none') {
                        try {
                                body.style.display='';
                        } catch(e) {
                                body.style.display = 'block';
                        }
                        document[id + '|pic'].src = '$docpath/toggleclose.gif';
                }
                else {
                        body.style.display = 'none';
                        document[id + '|pic'].src = '$docpath/toggleopen.gif';
                }
        }
}
</script>
EOT

    # add javascript to header
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JSCRIPT(TBODY)',$jScript);
}

# gets the url for the comment popup
sub _getCommentUrl {

    my ($comment, $skill, $user) = @_;

    my ($web, $topic) = _getCurrentTopic();

    my $url = TWiki::Func::getScriptUrl($web, $topic, 'oops',
        template => 'oopsgeneric',
        param1 => 'Skills Plugin Comment <noautolink>',
        param2 => "---++++ Comment for skill `$skill` by $user",
        param3 => "$user has logged the following comment next to skill `$skill`.",
        param4 => "<blockquote>$comment</blockquote> </noautolink>"
     );

    # use template/oppsgeneric.skills.tmpl
    return $url . '&cover=skills';
}

# =========================
# is user admin?
sub isAdmin {
    if ( $TWiki::Plugins::VERSION > 1.11 ) {
        # 1.12 and over
        return TWiki::Func::isAnAdmin();
    } else {
        my $user = $TWiki::Plugins::SESSION->{user};
        return $user->isAdmin();
    }
}

# checks if user is in ALLOWADDSKILLS
sub isAllowed {
    return 0 if TWiki::Func::isGuest();
    return 1 if isAdmin();

    return 1 unless TWiki::Func::getPreferencesFlag( "ALLOWADDSKILLS" ); 

    if ( $TWiki::Plugins::VERSION > 1.11 ) {
        # loop though array, check is group or user, if group find out if allowed. if user, check if its signed in user. else return 0
        foreach ( split( /,/, TWiki::Func::getPreferencesValue( "ALLOWADDSKILLS" ) ) ) {
            if ( TWiki::Func::isGroup( $_ ) ) {
                $_ =~ s/ //;
                return 1 if TWiki::Func::isGroupMember( $_ );
            } else {
                return 1 if ( TWiki::Func::getWikiName =~ m/$_/x );
            }
        }
        return 0;
    } else {
        my $user = $TWiki::Plugins::SESSION->{user};
        return $user->isInList( TWiki::Func::getPreferencesValue( "ALLOWADDSKILLS" ) );
    }
}

# =========================
# gets the images used in output table
sub _getImages {

    my $image = shift;

    my $docpath = _getDocPath();
        
    # Create image tags. Mainly to set a helpful alt attribute
    for ($image){
        /star/ and return "<img width='16' alt='*' align='top' src='$docpath/stargold.gif' height='16' border='0' />", last;
        /open/ and return "<img width='16' alt='-' align='top' src='$docpath/dot_ur.gif' height='16' border='0' />", last;
        /comment/ and return "<img width='16' alt='+' align='top' src='$docpath/note.gif' height='16' border='0' />", last;
        /clear/ and return "<img width='16' alt='Clear' align='top' src='$docpath/choice-cancel.gif' height='16' border='0' />", last;
    }
}

# path to twiki doc topic
sub _getDocPath {
    my $docpath = TWiki::Func::getPubUrlPath() . '/' . # /pub/
                  TWiki::Func::getTwikiWebname() . '/' . # TWiki/
                  'TWikiDocGraphics'; # doc topic

    return $docpath;
}

sub _getCurrentTopic {
    return ($globWeb, $globTopic);
}

# =========================
sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning( "- TWiki::Plugins::${pluginName}: $text" );
}

# logs actions in the standard twiki log
sub _Log {
    my $text = shift;

    my $logAction = $TWiki::cfg{Plugins}{$pluginName}{Log} || 1;

    my ($web, $topic) = _getCurrentTopic();

    if ($logAction) {
        $TWiki::Plugins::SESSION
        ? $TWiki::Plugins::SESSION->writeLog( "skills", "$web.$topic",
        $text )
        : TWiki::Store::writeLog( "skills", "$web.$topic", $text );
    }

    _Debug($text);
}

1;
