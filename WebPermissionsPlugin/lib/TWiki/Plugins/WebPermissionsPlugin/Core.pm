# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) Evolved Media Network 2005
# Copyright (C) Spanlink Communications 2006
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
#
# Author: Crawford Currie http://c-dot.co.uk
# Author: Eugen Mayer http://impressimpressive-media.de
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates
# WebPreferences in each affected web.
package TWiki::Plugins::WebPermissionsPlugin::Core;

use strict;

# BUGO: because WEBPERMISSIONS is using the same view to change and display,
# updated ACL's do not apply to this view.
# TWiki has already loaded the permissions that it is using, and some
# random plugins have already processed things based on the ACLs prior to
# the users change. THIS IS HORRIGIBILE
# IMO it needs to be either rest or save, though i'm going to lean to rest
# especially as we don't want to continue to presume that ACLs are topic based
# the advantage with save, is that it will re-direct to view on success (and
# resolve permissions issues)
sub WEBPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;
    my $query = $session->{cgiQuery};
    my $action = $query->param( 'web_permissions_action' );
    my $editing = $action && $action eq 'Edit';
    my $saving =  $action && $action eq 'Save';

    my @modes = split(/[\s,]+/,
                      $TWiki::cfg{Plugins}{WebPermissionsPlugin}{modes} ||
                        'VIEW,CHANGE' );

    my @webs = TWiki::Func::getListOfWebs( 'user' );
    my $chosenWebs = $params->{webs} || $query->param('webs');
    if( $chosenWebs ) {
        @webs = _filterList($chosenWebs, @webs);
    }

    my @knownusers;
    my $chosenUsers = $params->{users} || $query->param('users');

    my %table;
    foreach $web ( @webs ) {
        #TODO: use TWiki::Func::getRegularExpression(webNameRegex)
        next unless ($web=~/^(\w*)$/); #untaint before we do anything
        $web = $1;

        my $acls = _getACLs( \@modes, $web );

        unless( scalar( @knownusers )) {
            @knownusers = keys %$acls;
            if ($chosenUsers) {
                @knownusers = _filterList($chosenUsers, @knownusers);
            }
        }

        if( $saving ) {
            my $changes = 0;
            foreach my $user ( @knownusers ) {
                foreach my $op ( @modes ) {
                    my $onoff = $query->param($user.':'.$web.':'.$op);
                    if( $onoff && !$acls->{$user}->{$op} ||
                          !$onoff && $acls->{$user}->{$op} ) {
                        $changes++;
                        $acls->{$user}->{$op} = $onoff;
                    }
                }
            }
            # Commit changes to ACLs
            if( $changes ) {
                _setACLs( \@modes, $acls, $web );
            }
        }
        $table{$web} = $acls;
    }

    # Generate the table
    my $tab = '';

    my %images;
    foreach my $op ( @modes ) {
        if( -f TWiki::Func::getPubDir().'/TWiki/WebPermissionsPlugin/'.$op.'.gif' ) {
              $images{$op} =
                CGI::img( { src => TWiki::Func::getPubUrlPath().
                              '/TWiki/WebPermissionsPlugin/'.$op.'.gif' } );
              $tab .= $images{$op}.' '.$op;
        } else {
            $images{$op} = $op;
        }
    }

    $tab .= CGI::start_table( { border => 1, class => 'twikiTable' } );

    my $repeat_heads = $params->{repeatheads} || 0;
    my $repeater = 0;
    my $row;

    foreach my $user ( sort @knownusers ) {
        unless( $repeater ) {
            $row = CGI::th( '' );
            foreach $web ( @webs ) {
                $row .= CGI::th( $web );
            }
            $tab .= CGI::Tr( $row );
            $repeater = $repeat_heads;
        }
        $repeater--;
        $row = CGI::th( "$user " );
        foreach $web ( sort @webs ) {
            my $cell;
            foreach my $op ( @modes ) {
                if( $editing ) {
                    my %attrs = ( type => 'checkbox', name => $user.':'.$web.':'.$op );
                    $attrs{checked} = 'checked' if $table{$web}->{$user}->{$op};
                    $cell .= CGI::label( ($images{$op} || $op).CGI::input( \%attrs ));
                } elsif( $table{$web}->{$user}->{$op} ) {
                    $cell .= $images{$op} || $op;
                }
            }
            $row .= CGI::td( $cell );
        }
        $tab .= CGI::Tr( $row );
    }
    $tab .= CGI::end_table();

    if( $editing ) {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Save',  -class => 'twikiSubmit');
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Cancel',  -class => 'twikiSubmit' );
    } else {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Edit',  -class => 'twikiSubmit' );
    }
    my $page = CGI::start_form(
        -method => 'POST',
        -action => TWiki::Func::getScriptUrl( $web, $topic, 'view').
          '#webpermissions_matrix' );
    $page .= CGI::a({ name => 'webpermissions_matrix'});
    if( defined $chosenWebs ) {
      $page .= CGI::hidden( -name => 'webs', -value => $chosenWebs );
    }
    if( defined $chosenUsers ) {
      $page .= CGI::hidden( -name => 'users', -value => $chosenUsers );
    }

    $page .= $tab . CGI::end_form();
    return $page;
}
sub TOPICPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;

    #this is to redirect to the "no access" page if this tag is used in a non-view template.
    TWiki::UI::checkAccess( $session, $web, $topic,
                                'view', $session->{user} );

   my $disableSave = 'Disabled';
   $disableSave = '' if TWiki::Func::checkAccessPermission( 'CHANGE', 
                    TWiki::Func::getWikiUserName(), undef, $topic, $web );

   my $pluginPubUrl = TWiki::Func::getPubUrlPath().'/'.
            TWiki::Func::getTwikiWebname().'/WebPermissionsPlugin';

    #add the JavaScript
    my $jscript = TWiki::Func::readTemplate ( 'webpermissionsplugin', 'topicjavascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    TWiki::Func::addToHEAD('WebPermissionsPlugin', $jscript);

    my $templateText = TWiki::Func::readTemplate ( 'webpermissionsplugin', 'topichtml' );
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{save}%/g if ($disableSave eq '');
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{view}%/g unless ($disableSave eq '');
    $templateText = TWiki::Func::expandCommonVariables( $templateText, $topic, $web );

    my $topicViewerGroups = '';
    my $topicViewers = '';
    my $topicEditorGroups = '';
    my $topicEditors = '';
    my $unselectedGroups = '';
    my $unselectedUsers = '';

    my $acls = _getACLs( [ 'VIEW', 'CHANGE' ], $web, $topic);
    foreach my $user ( sort (keys %$acls) ) {
        my $isGroup;
        if (defined &TWiki::Func::isGroup) {
            $isGroup = TWiki::Func::isGroup( $user );
        } else {
            $isGroup = ($user =~ /Group$/);
        }
        if ( $acls->{$user}->{CHANGE} ) {
            $topicEditors .= '<OPTION>'.$user.'</OPTION>'
              unless $isGroup;
            $topicEditorGroups .= '<OPTION>'.$user.'</OPTION>'
              if $isGroup;
        } elsif ( $acls->{$user}->{VIEW} ) {
            $topicViewers .= '<OPTION>'.$user.'</OPTION>'
              unless $isGroup;
            $topicViewerGroups .= '<OPTION>'.$user.'</OPTION>'
              if $isGroup;
        } else {
            $unselectedUsers .= '<OPTION>'.$user.'</OPTION>'
              unless $isGroup;
            $unselectedGroups .= '<OPTION>'.$user.'</OPTION>'
              if $isGroup;
        }
    }
    $templateText =~ s/%EDITGROUPS%/$topicEditorGroups/g;
    $templateText =~ s/%EDITUSERS%/$topicEditors/g;
    $templateText =~ s/%VIEWGROUPS%/$topicViewerGroups/g;
    $templateText =~ s/%VIEWUSERS%/$topicViewers/g;
    $templateText =~ s/%UNSELECTEDGROUPS%/$unselectedGroups/g;
    $templateText =~ s/%UNSELECTEDUSERS%/$unselectedUsers/g;
    $templateText =~ s/%PLUGINNAME%/WebPermissionsPlugin/g;
    $templateText =~ s/%DISABLESAVE%/$disableSave/g;

    return $templateText;
}

sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    my $action = $query->param('topic_permissions_action');
    return unless (defined($action));#nothing to do with this plugin

    if ($action ne 'Save') {
        #SMELL: canceling out from, or just stoping a save seems to be quite difficult
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );
        throw Error::Simple( 'cancel permissions action' );
    }

    return if ($TWiki::Plugins::WebPermissionsPlugin::antiBeforeSaveRecursion == 1);
    $TWiki::Plugins::WebPermissionsPlugin::antiBeforeSaveRecursion = 1;

    #these lists only contain seelcted users (by using javascript to select the changed ones in save onclick)
    my @topicEditors = $query->param('topiceditors');
    my @topicViewers = $query->param('topicviewers');
    my @disallowedUsers = $query->param('disallowedusers');

   if ((@topicEditors || @topicViewers || @disallowedUsers)) {
        #TODO: change this to get modes from params
        my @modes = split(/[\s,]+/,$TWiki::cfg{Plugins}{WebPermissionsPlugin}{modes} ||
                           'VIEW,CHANGE' );
        my $acls = _getACLs( \@modes, $web, $topic);
        my ($userName, $userObj);
        foreach $userName (@topicEditors) {
            $acls->{$userName}->{'CHANGE'} = 1;
            $acls->{$userName}->{'VIEW'} = 1;
        }
        foreach $userName (@topicViewers) {
            $acls->{$userName}->{'CHANGE'} = 0;
            $acls->{$userName}->{'VIEW'} = 1;
        }
        foreach $userName (@disallowedUsers) {
            $acls->{$userName}->{'CHANGE'} = 0;
            $acls->{$userName}->{'VIEW'} = 0;
        }

        #TODO: what exactly happens on error?
        _setACLs( \@modes, $acls, $web, $topic );

        #read in what setACLs just saved, (don't grok why redirect looses the save)
        ($_[3], $_[0]) = TWiki::Func::readTopic($_[2],$_[1]);

        #SMELL: canceling out from, or just stoping a save seems to be quite difficult
        #return a redirect to view..
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );
        throw Error::Simple( 'permissions action saved' );

   }
}

# Filter a list of strings based on the filter expression passed in
sub _filterList {
    my $filter = shift;
    my %included;

    foreach my $expr (split(/,/, $filter)) {
        my $exclude = ($expr =~ s/^-//) ? 1 : 0;
        $expr =~ s/\*/.*/g;
        $expr =~ s/\?/./g;
        foreach my $item (@_) {
            # The \s's are needed to retain compatibility
            if ($item =~ /^\s*$expr\s*$/) {
                if ($exclude) {
                    delete $included{$item};
                } else {
                    $included{$item} = 1;
                }
            }
        }
    }
    return keys %included;
}

sub USERSLIST {
    my( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$wikiname';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';

    my @items;
    foreach my $item ( _getListOfUsers() ) {
        my $line = $format;
        $line =~ s/\$wikiname\b/$item/ge;
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        if (defined(&TWiki::Func::decodeFormatTokens)) {
            $line = TWiki::Func::decodeFormatTokens( $line );
        } else {
            $line =~ s/\$n\(\)/\n/gs;
            $line =~ s/\$n([^$TWiki::regex{mixedAlpha}]|$)/\n$1/gs;
            $line =~ s/\$nop(\(\))?//gs;
            $line =~ s/\$quot(\(\))?/\"/gs;
            $line =~ s/\$percnt(\(\))?/\%/gs;
            $line =~ s/\$dollar(\(\))?/\$/gs;
        }
        push( @items, $line );
    }
    return join( $separator, @items);
}

# Get a list of all registered users
sub _getListOfUsers {
    my @list;
    if (defined(&TWiki::Func::eachUser)) {
        my $it = TWiki::Func::eachUser();
        while ($it->hasNext()) {
            my $user = $it->next();
            push(@list, $user);
        }
    } else {
        # Compatibility; pre 4.2
        my $session = $TWiki::Plugins::SESSION;
        my $users = $session->{users};

        #if we have the UserMapping changes (post 4.0.2)
        if (defined (&TWiki::Users::getAllUsers)) {
            @list = @{$users->getAllUsers()};
        } else {
            $users->lookupLoginName('guest'); # load the cache

            @list =
              map {
                  my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                      $TWiki::cfg{UsersWebName}, $_);
                  $users->findUser( $t, "$w.$t");
              } values %{$users->{U2W}};
        }
        @list = map($_->wikiName(), grep(!$_->isGroup(), grep($_, @list)));

    }
    return @list;
}

# Get a list of all groups
sub _getListOfGroups {
    my @list;
    if (defined(&TWiki::Func::eachGroup)) {
        my $it = TWiki::Func::eachGroup();
        while ($it->hasNext()) {
            my $user = $it->next();
            push(@list, $user);
        }
    } else {
        # Compatibility; pre 4.2
        my $session = $TWiki::Plugins::SESSION;
        my $users = $session->{users};

        # if we have the UserMapping changes (post 4.0.2)
        if (defined (&TWiki::Users::getAllGroups)) {
            @list = map { $_->wikiName() }
              @{$session->{users}->getAllGroups()};
        } else {
            # This code assumes we are using TWiki topic based Group mapping
            $session->{search}->searchWeb(
                _callback     => sub {
                    my $ref = shift;
                    my $group = shift;
                    return unless $group;
                    my $groupObject = $ref->{users}->findUser( $group );
                    push (@{$ref->{list}}, $groupObject->wikiName())
                      if $groupObject;
                },
                _cbdata       =>  { list => \@list, users => $users },
                inline        => 1,
                search        => "Set GROUP =",
                web           => 'all',
                topic         => "*Group",
                type          => 'regex',
                nosummary     => 'on',
                nosearch      => 'on',
                noheader      => 'on',
                nototal       => 'on',
                noempty       => 'on',
                format	     => "\$web.\$topic",
                separator     => '',
               );
        }
    }
    return @list;
}

# Gets all users which have access to the given topic. This functions respects hierchical webs and climbs up the ladder
# if a web does not set any access permissions
sub getUsersByWebPreferenceValue {
    my( $mode, $web, $topic, $perm ) = @_;
    if($TWiki::cfg{EnableHierarchicalWebs}) {
       $_ = $web;
        my @webs = split("/");
       while(scalar(@webs) > 0) {
               my $curWeb = pop(@webs);
               my $users =  $TWiki::Plugins::SESSION->{prefs}->getWebPreferencesValue($perm."WEB".$mode, $curWeb, $topic );

               # we found users, so there have been settings to define acces. No need to check parent webs, as these settings are overriding
               return $users if(defined($users));

               #else continue with the parentwebs, if there are any
       }
    }
    else {
       # no hierchical webs, so just return the users of the current web
        return $TWiki::Plugins::SESSION->{prefs}->getWebPreferencesValue($perm."WEB".$mode, $web, $topic );
    }

    return undef;
}

# Formerly in FuncUsersContrib, this method has been imported to the plugin
# since we decided to go with iuterators for the users interface
# _getACLs( \@modes, $web, $topic ) -> \%acls
# Get the Access Control Lists controlling which registered users *and groups* are allowed to access the topic (web).
#    * =\@modes= - list of access modes you are interested in; e.g. [ "VIEW","CHANGE" ]
#    * =$web= - the web
#    * =$topic= - if =undef=  then the setting is taken as a web setting e.g. WEBVIEW. Otherwise it is taken as a topic setting e.g. TOPICCHANGE
# 
# =\%acls= is a hash indexed by *user name* (web.wikiname). This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean; 0 for access denied, non-zero for access permitted.
# <verbatim>
# my $acls = TWiki::Func::getACLs( [ 'VIEW', 'CHANGE', 'RENAME' ], $web, $topic );
# foreach my $user ( keys %$acls ) {
#     if( $acls->{$user}->{VIEW} ) {
#         print STDERR "$user can view $web.$topic\n";
#     }
# }
# </verbatim>
# The =\%acls= object may safely be written to e.g. for subsequent use with =setACLs=.
#
# __Note__ topic ACLs are *not* the final permissions used to control access to a topic. Web level restrictions may apply that prevent certain access modes for individual topics.
#
# *WARNING* when you use =setACLs= to set the ACLs of a web or topic, the change is not committed to the database until the current session exits. After =setACLs= has been called on a web or topic, the results of =getACLS= for that web/topic are *undefined* within the same session.
#

sub _getACLs {
    my( $modes, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }
    my @knownusers = _getListOfUsers();
    push(@knownusers, _getListOfGroups());

    my %acls;

    # By default, allow all to access all
    foreach my $user ( @knownusers ) {
        foreach my $mode ( @$modes ) {
            $acls{$user}->{$mode} = 1;
        }
    }

    #print STDERR "Got users ",join(',',keys %acls),"\n";
    foreach my $mode ( @$modes ) {
        foreach my $perm ( 'ALLOW', 'DENY' ) {
            my $users;
            if ($context eq 'WEB') {

               $users = getUsersByWebPreferenceValue($mode, $web, $topic, $perm);
                #print STDERR "$perm$context$mode ($web) is not defined\n" unless defined($users);
            } else {
                $users = $TWiki::Plugins::SESSION->{prefs}->getTopicPreferencesValue(
                    $perm.$context.$mode, $web, $topic );
               unless(defined($users)) { #as we did not find any settings in the topic, we have to look in the web prefs

                       #print STDERR "$perm$context$mode ($web, $topic) is not defined\n";
                       $users = getUsersByWebPreferenceValue($mode, $web, $topic,$perm);

                       #print STDERR $perm."WEB".$mode." ($web, $topic) is not defined\n" unless defined($users);
               };
            }
            next unless defined($users);

            my @lusers =
              grep { $_ }
                map {
                    my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                        $TWiki::cfg{UsersWebName}, $_);
                    $t;
                } split( /[ ,]+/, $users || '' );

            # expand groups
            my @users;
            while( scalar( @lusers )) {
                my $user = pop( @lusers );
                my $isGroup;
                if (defined &TWiki::Func::isGroup) {
                    $isGroup = TWiki::Func::isGroup( $user );
                } else {
                    $isGroup = $user =~ /Group$/;
                }
                if( $isGroup) {
                    if (defined &TWiki::Func::eachGroupMember) {
                        # expand groups and add individual users
                        my $it = TWiki::Func::eachGroupMember($user);
                        while ($it && $it->hasNext()) {
                            push( @lusers, $it->next() );
                        }
                    } else {
                        # Compatibility - pre 4.2
                        my $session = $TWiki::Plugins::SESSION;
                        my $users = $session->{users};
                        my $uo = $users->findUser($user);
                        # expand groups and add individual users
                        my $group = $uo->groupMembers();
                        push( @lusers, map { $_->wikiName() } @$group ) if $group;
                    }
                }
                push( @users, $user );
            }

            if( $perm eq 'ALLOW' ) {
                # If ALLOW, only users in the ALLOW list are permitted,
                # so change the default for all other users to 0.
                foreach my $user ( @knownusers ) {
                    #print STDERR "Disallow ",$user,"\n";
                    $acls{$user}->{$mode} = 0;
                }
                foreach my $user ( @users ) {
                    #print STDERR "Allow ",$user,"\n";
                    $acls{$user}->{$mode} = 1;
                }
            } else {
                foreach my $user ( @users ) {
                    #print STDERR "Deny ",$user,"\n";
                    $acls{$user}->{$mode} = 0;
                }
            }
        }
    }

    return \%acls;
}

# ---++ _setACLs( \@modes, \%acls, $web, $topic, $plainText )
# Set the access controls on the named topic.
#    * =\@modes= - list of access modes you want to set; e.g. [ "VIEW","CHANGE" ]
#    * =$web= - the web
#    * =$topic= - if =undef=, then this is the ACL for the web. otherwise it's for the topic.
#    * =\%acls= - must be a hash indexed by *user name* (web.wikiname). This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean value; 1 for allowed, and 0 for denied. See =getACLs= for an example of this kind of object.
#    * =$plainText - if set, permissions will be written using plain text (* Set) in the topic body rather than being stored in meta-data (the default)
# 
# Access modes used in \%acls that do not appear in \@modes are simply ignored.
# 
# If there are any errors, then an =Error::Simple= will be thrown.
# 
# *WARNING* when you use =setACLs= to set the ACLs of a web or topic, the change is not committed to the database until the current session exist. After =setACLs= has been called on a web or topic, the results of =getACLS= for that web/topic are *undefined*.

sub _setACLs {
    my( $modes, $acls, $web, $topic, $plainText ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    my @knownusers = _getListOfUsers();
    push(@knownusers, _getListOfGroups() );

    if( $plainText ) {
        $text .= "\n" unless $text =~ /\n$/s;
    }

    foreach my $op ( @$modes ) {
        my @allowed = grep { $acls->{$_}->{$op} } @knownusers;
        my @denied = grep { !$acls->{$_}->{$op} } @knownusers;
        # Remove existing preferences of this type in text
        $text =~ s/^(   |\t)+\* Set (ALLOW|DENY)$context$op =.*$//gm;
        $meta->remove('PREFERENCE', 'DENY'.$context.$op);
        $meta->remove('PREFERENCE', 'ALLOW'.$context.$op);

        if( scalar( @denied )) {
            # Work out the access modes
            my $name;
            my $set;
            if( scalar( @denied ) <= scalar( @allowed )) {
                $name = 'DENY'.$context.$op;
                $set = \@denied;
            } else {
                $name = 'ALLOW'.$context.$op;
                $set = \@allowed;
            }
            if ($plainText) {
                $text .= "   * Set $name = ". join(' ', @$set)."\n";
            } else {
                $meta->putKeyed( 'PREFERENCE',
                                 {
                                     name => $name,
                                     type => 'Set',
                                     title => 'PREFERENCE_'.$name,
                                     value => join(' ', @$set)
                                    }
                                );
            }
        }
    }

    # If there is an access control violation this will throw.
    TWiki::Func::saveTopic( $web, $topic,
                            $meta, $text, { minor => 1 } );
}

1;
