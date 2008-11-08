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

package TWiki::Plugins::SkillsPlugin::Tag;

use strict;

# =========================
# Will display a table of skills and rating for the defined user
sub _userSkills {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $params = shift;
    my $user = $params->{user}
        || TWiki::Func::getWikiName();
    my $twisty = $params->{twisty};

    my $rows = '';
    my $load = '';
    my $skills = TWiki::Plugins::SkillsPlugin::Func::_getUserSkills($user);
        
    my $star = TWiki::Plugins::SkillsPlugin::_getImages('star');
    my $lg_ur = TWiki::Plugins::SkillsPlugin::_getImages('open');
    my $comment = TWiki::Plugins::SkillsPlugin::_getImages('comment');

    my $docpath = TWiki::Plugins::SkillsPlugin::_getDocPath();

    # sort by category, then by skill
    my @skills = sort {
        lc $a->{category} cmp lc $b->{category}
                     ||
        lc $a->{name} cmp lc $b->{name};
    } @$skills;

    my $prevCat;
    foreach my $key (@skills) {
        if ($prevCat && $prevCat eq $key->{category}){
            # dont output the category
            $rows .= "<tr><td>$lg_ur $key->{name}</td>"; # skill
        } else {
            $rows .= "</tbody>";
            $rows .= "<tr class='skillsContent'><th colspan='6'>";
            if(lc$twisty eq 'open'){
                # twisty starts open
                $rows .= "<img name='$key->{category}|pic' src='$docpath/toggleclose.gif' border='0' alt='' align='center' />";
            } elsif (lc$twisty ne 'off' || !$twisty){
                $rows .= "<img name='$key->{category}|pic' src='$docpath/toggleopen.gif' border='0' alt='' align='center' />";
                # will hide the rows after loading
                $load .= "document.getElementById(\"$key->{category}\").style.display=\"none\"\n";
            }
            $rows .= "<a href=\"javascript:hideShow('$key->{category}');\">$key->{category}</a></th></tr>\n"; # category
            $rows .= "<tbody id='$key->{category}' >";
            $rows .= "<tr class='skillsContent'><td>$lg_ur $key->{name}</td>"; # skill
        }

        # rating
        my $i = 1;
        while ($i < $key->{rating}){
            $rows .= "<td>&nbsp;</td>";
            $i ++;
        }
        $rows .= "<td class='skillsRating'>$star</td>";
        $i ++;
        while ($i <= 4){
            $rows .= "<td>&nbsp;</td>";
            $i ++;
        }
                
        # comment
        if( $key->{comment} ){
            my $url = TWiki::Plugins::SkillsPlugin::_getCommentUrl($key->{comment}, $key->{name}, $user);
            $rows .= "<td><a href='$url' target='_blank'>$comment</a></td>";
        } else {
            $rows .= "<td>&nbsp;</td>";
        }
                
        $rows .= "</tr>\n";

        $prevCat = $key->{category};
    }
    # if no skills are found, $row will still be empty
    unless ($rows){
        $rows = "<tr><td colspan='5' bgcolor='yellow'><font color='red'><strong>$user has not added any skills.</strong></font> ([[%SYSTEMWEB%.SkillsPlugin]])</td></tr>";
    }

    my $footer = "[[%SYSTEMWEB%.SkillsBrowseAll][Browse Skills]]"
               . " | [[%SYSTEMWEB%.SkillsEditMySkills][Edit Your Skills]]</a>"
               . " | [[%SYSTEMWEB%.SkillsSearch][SearchSkills]]";

    my $table = <<"EOT";
<!-- SKILLSPLUGIN - USER SKILLS TABLE -->
<table id='skillsTable' class='skillsTable' cellpadding="2px" syle="margin:7px 0;">
<tr>
<th class='skillsHeading' colspan='6'><a href='%SCRIPTURL{view}%/%MAINWEB%/$user'>$user\'s Skills</a></th>
</tr><tr>
<td style="padding-left:120px;"></td><td class='skillsRatingHeader'>Ancient<br />Knowledge</td><td class='skillsRatingHeader'>Working<br />Knowledge</td><td class='skillsRatingHeader'>Expert</td><td class='skillsRatingHeader'>Guru</td><td>&nbsp;</td>
</tr>
<noautolink>
$rows
</tbody>
</noautolink>
<tr><td colspan='6' class='skillsFooter'><span style='float:left;'>$footer</span>
<!-- TODO: expand/collapse all links -->
<!--<span style='float:right;'><a href="javascript:hideShowAll('collapse')">Collapse</a> | <a href="javascript:hideShowAll('expand');">Expand</a></span>-->
</td></tr>
</table>
<script type="text/javascript">
// hides it after its loaded, so non javascript users can still see all of table
$load
</script>
EOT

    # add javascript to header
    TWiki::Plugins::SkillsPlugin::_addJScriptTbody() unless lc$twisty eq 'off';

    return $table;
}

# Lists the users who have the specific skill, or a skill in the specific category
sub _browseSkills {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $params = shift;

    my @paramCat = split( ',' , $params->{category});
    my @paramSkill = split( ',' , $params->{skill});
    my $twisty = $params->{twisty};

    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

    my $rows = '';
    my $load = '';
    my $userSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllUsersSkills();

    my $star = TWiki::Plugins::SkillsPlugin::_getImages('star');
    my $lg_ur = TWiki::Plugins::SkillsPlugin::_getImages('open');

    my $docpath = TWiki::Plugins::SkillsPlugin::_getDocPath();

    foreach my $cat (sort keys %$allSkills){
        # skip categories that are not defined
        next if(@paramCat and !grep(/^(\s)?$cat(\s)?$/i, @paramCat));

        $rows .= "</tbody>";
        $rows .= "<tr><th colspan='6'>";
        if(lc$twisty eq 'open' || lc$twisty eq 'top'){
            # twisty starts open
            $rows .= "<img name='$cat|pic' src='$docpath/toggleclose.gif' border='0' alt='' align='center' />";
        } elsif (lc$twisty ne 'off' || !$twisty){
            $rows .= "<img name='$cat|pic' src='$docpath/toggleopen.gif' border='0' alt='' align='center' />";
            # will hide the rows after loading
            $load .= "hideShow('$cat');\n";
        }
        $rows .= "<a href=\"javascript:hideShow('$cat');\">$cat</a></th></tr>\n"; # category
        $rows .= "<tbody id='$cat' >";
        @{ $allSkills->{$cat} } = sort @{ $allSkills->{$cat} };

        for my $skill ( 0 .. $#{ $allSkills->{$cat} } ) {
            my $skill = $allSkills->{$cat}->[$skill];
            # skip skills not defined
            next if(@paramSkill and !grep(/^(\s)?$skill(\s)?$/i, @paramSkill));
            # skill
            $rows .= "<tr><td colspan='6' class='head2'> $lg_ur ";
            unless (lc$twisty eq 'open' || lc$twisty eq 'off'){
                $load .= "hideShowRow('$cat|$skill');\n";
            }
            $rows .= "<a href=\"javascript:hideShowRow('$cat|$skill');\">";
            $rows .= "$skill</a></td></tr>\n";

            my $id = 0; # unique id for each row used in twisty (due to problems with nested <tbody>)
            foreach my $user (sort keys %$userSkills){
                if($userSkills->{$user}->{$skill}){
                    $rows .= "<tr id='$cat|$skill\_$id'><td class='userRow'>$lg_ur [[%MAINWEB%.$user][$user]]</td>"; # user
                    # rating
                    my $i = 1;
                    while ($i < $userSkills->{$user}->{$skill}->{rating}){
                        $rows .= "<td>&nbsp;</td>";
                        $i ++;
                    }
                    $rows .= "<td class='skillsRating'>$star</td>";
                    $i ++;
                    while ($i <= 4){
                        $rows .= "<td>&nbsp;</td>";
                        $i ++;
                    }

                    # comment
                    if ($userSkills->{$user}->{$skill}->{comment}){
                        my $image = TWiki::Plugins::SkillsPlugin::_getImages('comment');
                        my $url = TWiki::Plugins::SkillsPlugin::_getCommentUrl(
                            $userSkills->{$user}->{$skill}->{comment},
                            $skill,
                            $user
                        );
                        $rows .= "<td><a href='$url' target='_blank'>$image</a></td>";
                    } else {
                        $rows .= "<td>&nbsp;</td>";
                    }
                                        
                    $rows .= "</tr>\n";
                    $id ++;
                }
                                
            }
        }
    }
        
    # $rows will still be empty if no skills have been set up
    unless ($rows){
        $rows = "<tr><td colspan='5' bgcolor='yellow'><font color='red'><strong>"
              . "No skills have been set up. Go to [[%SYSTEMWEB%.SkillsPlugin]] for more information."
              . "</strong></font></td></tr>";
    }
        
    # output table
    my $table = <<"EOT";
<!-- SKILLSPLUGIN - LIST SKILLS -->
<table class='skillsTable'>
<tr>
<th class='skillsHeading' colspan='6'><a href='%SCRIPTURL{view}%/%SYSTEMWEB%/SkillsPlugin'>List All Skills</a></th>
</tr><tr>
<td style="padding-left:200px;"></td><td class='skillsRatingHeader'>Ancient<br />Knowledge</td><td class='skillsRatingHeader'>Working<br />Knowledge</td><td class='skillsRatingHeader'>Expert</td><td class='skillsRatingHeader'>Guru</td>
</tr>
$rows
</table>
<script type="text/javascript">
// hides it after its loaded, so non javascript users can still see all of table
$load
</script>
EOT

    # Add javascript to hide/show based on row id's
    my $jScript = <<"EOT";
<script type="text/javascript">
function hideShowRow(id){
        var i = '0';
        var body;
                while (body = document.getElementById(id + '_' + i)){
                        if (body.style.display == 'none') {
                                try {
                                        body.style.display='';
                                } catch(e) {
                                        body.style.display = 'block';
                                }
                        }
                        else {
                                body.style.display = 'none';
                        }
                        i ++;
                }
        }
</script>
EOT
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JSCRIPT(ROW)',$jScript) unless lc$twisty eq 'off';

    # add javascript(tbody) to header
    TWiki::Plugins::SkillsPlugin::_addJScriptTbody() unless lc$twisty eq 'off';

    return $table;
}

# creates a form allowing users to edit their skills
sub _editSkills {

    my $user = TWiki::Func::getWikiName();

    my $addeditMessage = '';

    # warning for guest
    if( $user =~ /^($TWiki::cfg{DefaultUserWikiName}|$TWiki::cfg{DefaultUserLogin})$/ ){
        $addeditMessage = "<tr><td colspan='6' bgcolor='yellow'><font color='red'><strong>You need to log in before you manage your skills.</strong></font></td></tr>";
    } else {
        $addeditMessage = '%ADDEDITMESSAGE%';
    }

    # to clear textbox
    my $clearPic = TWiki::Plugins::SkillsPlugin::_getImages('clear');
    my $clear = "<span id='clearComment' style='display:none;'><a href='javascript:clearText(document.skillsForm.comment);'>$clearPic</a></span>";

    # get categories
    my $categories = _showCategories({format => "<option value='\$category'>\$category</option>"});

    my $outHtml = <<"EOT";
<!-- SKILLSPLUGIN - EDIT SKILLS -->
<form name="skillsForm" method="post" action="%TOPIC%">
<table class="skillsForm">
<tr><th colspan="6"><a href="%SCRIPTURL{view}%/%SYSTEMWEB%/SkillsPlugin">Edit Your Skills (!$user)</a></th></tr>
<tr><td><strong>Category</strong></td>
<td colspan="5"><select name="category" onchange='setSkills(this.form.category);'>
<option selected="selected" value="0">Select a category...</option>
$categories
</select></td>
</tr>
<tr><td><strong>Skill</strong></td>
<td colspan="5"><select name="skill" onchange='setRating(this.form.skill);'>
<option value="0" selected="selected">Select a category above...</option>
</select></td></tr>
<tr><td><strong>Rating</strong></td>
<td class="skillsFormRating">Ancient<br />Knowledge</td><td class="skillsFormRating"> Working<br />Knowledge</td><td class="skillsFormRating">Expert</td><td class="skillsFormRating">Guru</td><td class="skillsFormRating">None</td></tr>
<tr><td></td>
<td class="skillsFormRating"><input type="radio" name="rating" value="1" /></td>
<td class="skillsFormRating"><input type="radio" name="rating" value="2" /></td>
<td class="skillsFormRating"><input type="radio" name="rating" value="3" /></td>
<td class="skillsFormRating"><input type="radio" name="rating" value="4" /></td>
<td class="skillsFormRating"><input type="radio" name="rating" value="0" /></td>
</tr>
<tr><td><strong>Comment</strong></td>
<td colspan="5"><input name="comment" type="text" size="35" onkeypress="javascript:showCancelComment();" />&nbsp;&nbsp;$clear&nbsp;&nbsp;<em>Optional</em></td>
</tr>
<tr><td colspan="6" class="skillsFormRating"><input name="editskills" type="Submit" value="Add/Edit" class="twikiSubmit"></td></tr>
$addeditMessage
</table>
</form>
EOT

    # add javascript to header
    TWiki::Func::addToHEAD('SKILLSPLUGIN_EDITSKILLS_JSCRIPT',TWiki::Plugins::SkillsPlugin::_skillJScript('skillsForm'));

    return $outHtml;
}

# creates a basic search form
sub _searchForm {

### HTML FORM ###

    my $categories = _showCategories({format => "<option value='\$category'>\$category</option>"});

    my $outHtml = <<"EOT";
<!-- SKILLSPLUGIN - SEARCH SKILLS -->
<form name="searchskills" method="post" action="%TOPIC%">
<table class="skillsForm">
<tr><th colspan="4"><a href="%SCRIPTURL{view}%/%SYSTEMWEB%/SkillsPlugin">Search Skills</a></th></tr>
<!-- Category -->
<tr><td><strong>Category</strong></td>
<td><select name="category" onchange='setSkills(this.form.category);'>
<option selected="selected" value="0">Select a category...</option>
$categories
</select>
</td>
<!-- Skill -->
<td><strong>Skill</strong></td>
<td>
<select name="skill">
<option value="0" selected="selected">Select a category...</option>
</select>
</td>
</tr>
<tr><td><strong>Rating</strong></td>
<td colspan="3">Between &nbsp;&nbsp;
<select name="ratingFrom">
<option value="1">Ancient Knowledge</option>
<option value="2" selected="selected">Working Knowledge</option>
<option value="3">Expert</option>
<option value="4">Guru</option>
</select>
&nbsp;&nbsp; and &nbsp;&nbsp;
<select name="ratingTo">
<option value="1">Ancient Knowledge</option>
<option value="2">Working Knowledge</option>
<option value="3">Expert</option>
<option value="4" selected="selected">Guru</option>
</select>
</td>
</tr>
<tr><td colspan="4" class="skillsFormRating"><input name="searchskills" type="Submit" value="Search" class="twikiSubmit"></td></tr>
</table>
</form>

%SKILLSSEARCHRESULTS%
EOT

    return $outHtml;
}

# allows the user to print all categories in format of their choice
sub _showCategories {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $params = shift;
    my $format = $params->{format};
    my $separator = $params->{separator};
        
    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$category' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    my $text = '';
    my $line = '';
    
    my $cats = TWiki::Plugins::SkillsPlugin::Func::_getAllCategories();

    $text = join(
        $separator,
            map {
                $line = $format;
                $line =~ s/\$category/$_/go;
                $line;
        } @$cats
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
# TODO: specify multiple categories? needed?
sub _showSkills {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $params = shift;
    my $cat = $params->{category};
    my $format = $params->{format};
    my $separator = $params->{separator};
    my $prefix = $params->{prefix};
    my $suffix = $params->{suffix};

    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go;
    $suffix =~ s/\$n/\n/go;


    my $text = '';
    my $line = '';

    # skills in a specific category
    if ($cat){
        my $skills = TWiki::Plugins::SkillsPlugin::Func::_getSkillsInCategory($cat);
        $text = join(
            $separator,
                map {
                    $line = $format;
                    $line =~ s/\$skill/$_/go;
                    $line;
            } @$skills
        );
                
        return $text;
                
    } 
    # all skills and categories
    else {
        my $catSeparator = $params->{categoryseparator};
        $catSeparator = "\n" unless ( $catSeparator ne '' );

        my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

        foreach my $cat (sort keys %$allSkills){
            my $prefixLine = $prefix;
            $prefixLine =~ s/\$category/$cat/go;
            $prefixLine =~ s/\$n/\n/go;
            $text .= $prefixLine;

            @{ $allSkills->{$cat} } = sort @{ $allSkills->{$cat} };
            $text .= join(
                $separator,
                map {
                    $line = $format;
                    $line =~ s/\$category/$cat/go;
                    $line =~ s/\$skill/$_/go;
                    $line;
                } @{ $allSkills->{$cat} }
            );

            my $suffixLine = $suffix;
            $suffixLine =~ s/\$category/$cat/go;
            $suffixLine =~ s/\$n/\n/go;
            $text .= $suffixLine;

            # seperate each category
            $text .= $catSeparator;
        }
                
        return $text;
    }

}


1;
