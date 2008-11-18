# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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

package TWiki::Plugins::SkillsPlugin::Query;

use strict;

# Users add/edit a skill
sub _addEditSkill {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $cat, $skill, $rating, $comment ) = @_;

    my $user =  TWiki::Func::getWikiName();

    # guest cant have skills
    return if( $user =~ /^($TWiki::cfg{DefaultUserWikiName}|$TWiki::cfg{DefaultUserLogin})$/  );

        # no category or skill selected
        if($cat eq '0' || $skill eq '0'){
            return "<tr><td colspan='6' bgcolor='yellow'><font color='red'><strong>You have not selected a category and/or a skill<strong></font></td></tr>";
        }

    my $skills = TWiki::Plugins::SkillsPlugin::Func::_getUserSkills($user);
    if($rating == 0){
        # remove skill
        my @newSkills = ();
        foreach my $key (@$skills){
            unless($key->{'category'} eq $cat
            && $key->{'name'} eq $skill){
                push(@newSkills, $key);
                }
            }
        TWiki::Plugins::SkillsPlugin::Func::_saveUserSkills($user, \@newSkills);
        return "<tr><td colspan='6' bgcolor='yellow'><font color='red'><strong>Removed skill '$skill'.</strong></font></td></tr>";
    } else {
        # add/edit skill
        push (@$skills, {
                name => $skill,
                category => $cat,
                rating => $rating,
                comment => $comment
            }
        );
        TWiki::Plugins::SkillsPlugin::Func::_saveUserSkills($user, $skills);
        return "<tr><td colspan='6' bgcolor='yellow'><font color='red'><strong>Add/Edited skill '$skill'.</strong></font></td></tr>";
    }
}

# Admins adding a new category
sub _createCategory {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $cat = shift;

    # ensure only alphanumeric characters and underscore
    $cat = TWiki::Plugins::SkillsPlugin::Func::_cleanInput($cat);

    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

    unless($allSkills->{$cat}){
        $allSkills->{$cat} = [];
        TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);
                
        TWiki::Plugins::SkillsPlugin::_Log("Added category '$cat'");
                
        return "Category '$cat' has been added.";
    } else {
        return "Category '$cat' already exists.";
    }
        
}

# Admins renaming a category
sub _renameCategory {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $oldcat, $newcat ) = @_;

    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();
    if($allSkills->{$oldcat}){
        unless ($allSkills->{$newcat}){
            # skills.txt
            my $skills = $allSkills->{$oldcat};
            delete($allSkills->{$oldcat});
            push @{ $allSkills->{$newcat} }, @$skills;
            TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);

            # users meta
            TWiki::Plugins::SkillsPlugin::Func::_renameInUsers($oldcat, $newcat);

            TWiki::Plugins::SkillsPlugin::_Log("Renamed category '$oldcat' to '$newcat'" );
                        
            return "Category '$oldcat' has been renamed to '$newcat'.";
        } else {
            return "Category '$newcat' already exists.";
        }
    } else {
        return "Category '$oldcat' does not exist.";
    }

}

# Admins deleting a category
sub _deleteCategory {
    require TWiki::Plugins::SkillsPlugin::Func;

    my $cat = shift;

    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();
    if (defined $allSkills->{$cat}){
        # skills.txt
        delete($allSkills->{$cat});
        TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);

        # users meta
        TWiki::Plugins::SkillsPlugin::Func::_deleteFromUsers($cat);
        
        TWiki::Plugins::SkillsPlugin::_Log("Deleted category '$cat'");

        return "Category '$cat' has been deleted.";
    } else {
        return "Category '$cat' does not exist";
    }

}

# =========================
# Admins add a new skill
sub _createSkill {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $skill, $cat ) = @_;

    $skill = TWiki::Plugins::SkillsPlugin::Func::_cleanInput($skill);
                
    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

    unless(grep(/^$skill$/, @{ $allSkills->{$cat} })){
        push(@{ $allSkills->{$cat} }, $skill );
        TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);

        TWiki::Plugins::SkillsPlugin::_Log("New skill '$skill' in category '$cat'");

        return "Skill '$skill' has been created.";
    } else {
        return "Skill '$skill' already exists.";
    }

}

# Admins rename an existing skill
sub _renameSkill {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $cat, $oldskill, $newskill ) = @_;

    $newskill = TWiki::Plugins::SkillsPlugin::Func::_cleanInput($newskill);

    # skills.txt
    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

    if (grep(/^$oldskill$/, @{ $allSkills->{$cat} })){
        # skill exists
        unless(grep(/^$newskill$/, @{ $allSkills->{$cat} })){

            my @skills = ();

            # loop through all skills in category, pushing
            # those that are not what we looking for
            foreach my $key ($allSkills->{$cat}){
                foreach my $i (@$key){
                    unless($i eq $oldskill){
                        push(@skills, $i);
                    }
                }
            }

            # push renamed skill
            push(@skills, $newskill );

            # save
            @{ $allSkills->{$cat} } = @skills;
            TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);

            # users meta
            TWiki::Plugins::SkillsPlugin::Func::_renameInUsers($cat, undef, $oldskill, $newskill);

            TWiki::Plugins::SkillsPlugin::_Log("Renamed skill '$oldskill' to '$newskill' in category '$cat'");

            return "Skill '$cat|$oldskill' has been renamed to '$newskill'.";
        } else {
            # renamed skill already exists
            return "Skill '$cat|$newskill' already exists.";
        }
    } else {
        # skill does not exist
        return "Skill '$cat|$oldskill' does not exist.";
    }

}

# Admins moving a skill to a different category
sub _moveSkill {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $skill, $oldcat, $newcat ) = @_;

    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();
        
    if (grep(/^$skill$/, @{ $allSkills->{$oldcat} })){
        # skill exists in old category
        unless (grep(/^$skill$/, @{ $allSkills->{$newcat} })){
            # skill does not exist in new category
            my @skills = ();
                        
            # loop through all skills in old category,
            # removing the skill to be moved
            foreach my $key ($allSkills->{$oldcat}){
                foreach my $i (@$key){
                    unless($i eq $skill){
                        push(@skills, $i);
                    }
                }
            }
            @{ $allSkills->{$oldcat} } = @skills;

            # add the skill to the new category
            push(@{ $allSkills->{$newcat} }, $skill);

            # save
            TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);
                                        
            # users
            TWiki::Plugins::SkillsPlugin::Func::_moveInUsers($skill, $oldcat, $newcat);

            TWiki::Plugins::SkillsPlugin::_Log("Skill '$skill' has been moved from '$oldcat' to '$newcat'");

            return "Skill '$skill' has been moved from '$oldcat' to '$newcat'.";

        } else {
            return "Skill '$skill' already exists in category '$newcat'.";
        }
    } else {
        return "Skill '$skill' does not exist in category '$oldcat'.";
    }
}


# Admins delete an existing skill
sub _deleteSkill {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $cat, $skill ) = @_;

    # skills.txt
    my $allSkills = TWiki::Plugins::SkillsPlugin::Func::_getAllSkills();

    my @skills = ();

    # TODO: Check skill exists
    foreach my $key ($allSkills->{$cat}){
        foreach my $i (@$key){
            unless($i eq $skill){
                push(@skills, $i);
            }
        }
    }
    @{ $allSkills->{$cat} } = @skills;
    TWiki::Plugins::SkillsPlugin::Func::_saveAllSkills($allSkills);

    # users meta
    TWiki::Plugins::SkillsPlugin::Func::_deleteFromUsers($cat, $skill);

    TWiki::Plugins::SkillsPlugin::_Log("Deleted skill '$skill' from category '$cat'");

    return "Skill '$cat|$skill' has been deleted.";

}

# =========================
# Answers a search query
sub _searchSkills {
    require TWiki::Plugins::SkillsPlugin::Func;

    my( $cat, $skill, $ratingFrom, $ratingTo, $topicSearch ) = @_;

    my $users = TWiki::Plugins::SkillsPlugin::Func::_getListOfUsers(); # user topics
    my $web = TWiki::Func::getMainWebname();

    if($topicSearch){
        my $result =  TWiki::Func::searchInWebContent($topicSearch , $web, $users, { casesensitive => 0, files_without_match => 1 } );

        # replace all users array with users who match search
        @$users = keys(%$result);
    }
                
    my $rows = '';
        
    my $star =  TWiki::Plugins::SkillsPlugin::_getImages('star');

    my $matches = 0;
    foreach my $user (sort @$users ) {
        my $skills = TWiki::Plugins::SkillsPlugin::Func::_getUserSkills($user);
        next unless @$skills; # no skills

        foreach my $key (@$skills){
            if( $cat eq $key->{category}
            and $skill eq $key->{name}
            and $key->{rating} >= $ratingFrom and $key->{rating} <= $ratingTo){
                $rows .= "<tr><td class='userRow'> [[%MAINWEB%.$user][$user]]</td>"; # user

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
                if($key->{comment}){
                    my $image = TWiki::Plugins::SkillsPlugin::_getImages('comment');
                    my $url = TWiki::Plugins::SkillsPlugin::_getCommentUrl(
                        $key->{comment},
                        $key->{name},
                        $user
                    );
                    $rows .= "<td><a href='$url' target='_blank'>$image</a></td>";
                } else {
                    $rows .= "<td>&nbsp;</td>";
                }


                $rows .= "</tr>\n";
                               
                $matches ++;
            } # match search
                        
        } # each skill
    } # each user

    # output table
    my $searchResults = <<"EOT";
<!-- SKILLSPLUGIN - SEARCH SKILLS -->
<table class='skillsTable'>
<tr>
<th class='skillsHeading' colspan='6'><a href='%SCRIPTURL{view}%/%SYSTEMWEB%/SkillsPlugin'>Skills Search Results</a></th>
</tr><tr>
<td style="padding-left:200px;"></td><td class='skillsRatingHeader'>Ancient<br />Knowledge</td><td class='skillsRatingHeader'>Working<br />Knowledge</td><td class='skillsRatingHeader'>Expert</td><td class='skillsRatingHeader'>Guru</td>
</tr>
<tr><th colspan='6'>Search Results... (Category: <em>%URLPARAM{"category"}%</em>; Skill: <em>%URLPARAM{"skill"}%</em>; Matches: <em>$matches</em>)</th></tr>
$rows
</table>
EOT

    return $searchResults;

}

1;
