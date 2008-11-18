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

package TWiki::Plugins::SkillsPlugin::Func;

use strict;

# =========================
# Gets the skills data from the user topic
sub _getUserSkills {
    my $userTopic = shift;
    my $mainWeb = TWiki::Func::getMainWebname();

    my( $meta, undef ) = TWiki::Func::readTopic( $mainWeb, $userTopic );
    my @userSkills = $meta->find('SKILLS');
    return (\@userSkills);
}

# Saves the users skills data
sub _saveUserSkills {
    my( $user, $userSkills ) = @_;
    my $mainWeb = TWiki::Func::getMainWebname();

    my( $meta, $text ) = TWiki::Func::readTopic( $mainWeb, $user );

    $meta->remove('SKILLS');
    foreach my $key (@$userSkills){
        $meta->putKeyed('SKILLS',$key); 
    }
    my $error = TWiki::Func::saveTopic( $mainWeb, $user, $meta, $text, { dontlog => 1, comment=> 'SkillsPlugin', minor => 1 });
    if ($error){
        TWiki::Plugins::SkillsPlugin::_Warn("saveUserSkills error - $error");
    }
}

# Gets the skills data from all the user topics
sub _getAllUsersSkills {
    my $users = _getListOfUsers();
    my %allUsersSkills = ();

    foreach my $user (@$users){
        my $skills = _getUserSkills($user);
        foreach my $skill (@$skills){
            $allUsersSkills{$user}->{$skill->{name}}->{rating} = $skill->{rating};
            $allUsersSkills{$user}->{$skill->{name}}->{comment} = $skill->{comment};
        }
    }
    return (\%allUsersSkills);
}

# Delete either the category or skill from users meta
sub _deleteFromUsers {
    my ($cat, $skill) = @_;

    my $users = _getListOfUsers();

    foreach my $user (@$users){
        my $skills = _getUserSkills($user);
        my @newSkills = ();
        if($cat && !$skill){
            # delete category
            foreach my $key (@$skills) {
                unless($key->{'category'} eq $cat){
                    push(@newSkills, $key);
                }
            }
        }
        elsif ($cat && $skill){
            # delete skill
            foreach my $key ( @$skills ) {
                unless( $key->{'category'} eq $cat &&
                        $key->{'name'} eq $skill ){
                        
                    push(@newSkills, $key);
                }
            }
        }
        _saveUserSkills($user, \@newSkills);
    }
}

# Rename either the category or the skill from the users meta
sub _renameInUsers {
    my ($cat, $newCat, $skill, $newSkill) = @_;


    my $users = _getListOfUsers();

    foreach my $user (@$users){
        my $skills = _getUserSkills($user);
        my @newSkills = ();

        if($cat && $newCat && !$skill){
            # rename category
            foreach my $key (@$skills) {
                unless($key->{'category'} eq $cat){
                    # no change
                    push(@newSkills, $key);
                } else {
                    # rename
                    my %renamed = ( 'category' => $newCat,
                                    'name' => $key->{'name'},
                                    'rating' => $key->{'rating'} );
                   push(@newSkills, \%renamed);
                }
            }
        }
        elsif ($cat && $skill && $newSkill){
            # rename skill
            foreach my $key (@$skills) {
                unless( $key->{'category'} eq $cat &&
                        $key->{'name'} eq $skill ){
                        
                    # no change
                    push(@newSkills, $key);
                } else {
                    # rename
                    my %renamed = ( 'category' => $cat,
                                    'name' => $newSkill,
                                    'rating' => $key->{'rating'} );
                    push(@newSkills, \%renamed);
                }
            }
        }
        _saveUserSkills($user, \@newSkills);
    }

}

sub _moveInUsers {
    my ($skill, $oldcat, $newcat) = @_;

    my $users = _getListOfUsers();

    foreach my $user (@$users){
        my $skills = _getUserSkills($user);
        my @newSkills = ();

        foreach my $key (@$skills) {
            unless( $key->{'category'} eq $oldcat &&
                    $key->{'name'} eq $skill ){
                    
                # no change
                push(@newSkills, $key);
            } else {
                # move
                my %moved = ( 'category' => $newcat,
                              'name' => $skill,
                              'rating' => $key->{'rating'} );
                push(@newSkills, \%moved);
            }
        }
        _saveUserSkills($user, \@newSkills);
    }

}

# Gets a list of all the users from the users topic
sub _getListOfUsers {
    my @users = ();
    my $mainWeb = TWiki::Func::getMainWebname();

    my (undef, $text) = TWiki::Func::readTopic(
        $mainWeb, $TWiki::cfg{UsersTopicName} );

        foreach my $line ( split( /\r?\n/, $text )) {
            if( $line =~ m/^\s*\* ($TWiki::regex{webNameRegex}\.)?(\w+)\s*(?:-\s*(\S+)\s*)?-\s*\d+ \w+ \d+\s*$/o ) {
                my $web = $1 || $mainWeb;
                my $wikiName = $2;
                if(TWiki::Func::topicExists($web, $wikiName) && $wikiName !~ m/TWiki.*|UnknownUser|AdminUser|AdminGroup|RegistrationAgent|WikiGuest/){
                    push(@users, $wikiName);
                }
            }
        }

        return (\@users);
}

# =========================
# Gets all the available categories and skills
# skills.txt 'category:skill1,skill2,skill3...\n'
sub _getAllSkills {
    # no skills
    my $workArea =  TWiki::Func::getWorkArea( 'SkillsPlugin' );

    return unless (my $file = TWiki::Func::readFile( $workArea . '/skills.txt'));

    my %allSkills = ();

    my @text = grep { !/^\#.*/ } split('\n', $file);
    foreach my $line (@text){
        $line =~ s/(\w*)://g;
        my $cat = $1;
        my @skills = split(',', $line);
        push @{ $allSkills{$cat} }, @skills;
    }
    return (\%allSkills);
}

# Saves all the available categories and skills
sub _saveAllSkills {
    my $allSkills = shift;
    my $out = "# This file is generated. Do NOT edit!\n";

    foreach my $cat (keys %$allSkills){
        $out .= "$cat:" . join(',', @{ $allSkills->{$cat} } ) . "\n";
    }

    my $workArea =  TWiki::Func::getWorkArea( 'SkillsPlugin' );

    TWiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

# Gets all the categories and returns in array
sub _getAllCategories {
    my $allSkills = _getAllSkills();

    my @cats = ();
    foreach my $cat (sort keys %$allSkills){
        push(@cats, $cat);
    }

    return \@cats;
}

# Gets all the skills in a particular category
sub _getSkillsInCategory {
    my $cat = shift;
    my $allSkills = _getAllSkills();

    return $allSkills->{$cat};
}

# =========================
# checks input for new categories/skills
# TODO: maybe move to ../SkillsPlugin.pm
# this module is to do with storage in skills.txt
# and users meta data
sub _cleanInput {
    my $in = shift;
    my $alphaNum = TWiki::Func::getRegularExpression( 'mixedAlphaNum' );
    $in =~ s/[- \/]/_/go;
    $in =~ s/[^${alphaNum}_]//go;
    $in =~ s/^(.{20}).*/$1/;
    return $in;
}


1;

#EOF
