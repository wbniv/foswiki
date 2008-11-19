# Immediate Notify Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Walter Mundt, emage@spamcop.net
# Copyright (C) 2003 Akkaya Consulting GmbH, jpabel@akkaya.de
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
# This plugin supports immediate notification of topic saves.
#
# =========================
package TWiki::Plugins::ImmediateNotifyPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug %methodHandlers
);
use Data::Dumper;

# This should always be $Rev: 15564 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15564 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ImmediateNotifyPlugin';    # Name of this Plugin

sub debug { TWiki::Func::writeDebug(@_) if $debug; }

sub warning {
    TWiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.011 ) {
        warning("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    my $prefPrefix = "\U$pluginName\E_";

    # Get plugin debug flag
    TWiki::Func::getPreferencesFlag( $prefPrefix."DEBUG" );

    $methods = TWiki::Func::getPreferencesValue( $prefPrefix . "METHODS" );
    if ( !defined($methods) ) {
        warning("- $pluginName: No METHODS defined in plugin topic, defaulting to SMTP");
        $methods = "SMTP";
        return 0;
    }
    %methodHandlers = ();
    foreach $method ( split ' ', $methods ) {
        debug("- $pluginName: Loading method $method...");
        $modulePresent = eval { require "TWiki/Plugins/ImmediateNotifyPlugin/$method.pm"; 1 };
        unless ( defined($modulePresent) ) {
            warning("- ${pluginName}::$method failed to load: $@");
            debug("- ${pluginName}::$method failed to load: $@");
            next;
        }

        my $module = "TWiki::Plugins::ImmediateNotifyPlugin::${method}::";
        if ( eval $module . 'initMethod($topic, $web, $user)' ) {
            $methodHandlers{$method} = eval '\&' . $module . 'handleNotify';
        }
        else {
            debug("- $pluginName: initMethod failed");
        }

        if ( defined( $methodHandlers{$method} ) ) {
            debug("- ImmediateNotifyPlugin::$method OK");
        }
        else {
            warning("- ${pluginName}::$method failed to load");
        }
    }
    unless (%methodHandlers) {
        warning("- $pluginName: No methods available, initialization failed");
        return 0;
    }

    # Plugin correctly initialized
    debug("- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK");
    return 1;
}

sub processName {
    my ( $name, $users, $groups ) = @_;
    debug("- $pluginName: Processing name $name");
    return if ( length($name) == 0 );
    if ( $name =~ /Group$/go ) {
        return if exists $groups->{$name};    # don't reprocess groups

        $groups->{$name} = undef; # add to hash, leave undef unless GROUP is set
        $groupTopic = TWiki::Func::readTopicText( $mainWeb, $name );
        unless ( defined($groupTopic) ) {
            warning("- $pluginName: Group topic \"$mainWeb.$name\" not found!");
            return;
        }
        $groupTopic =~ /^\t+\* Set GROUP =(.+)\n[^\t]/sm;
        my @groupMembers = split /[\r\n\s]*[,\s][\r\n\s]*/, $1;
        if (@groupMembers) {
            debug("- $pluginName: Group $name consists of: @groupMembers");
        }
        else {
            debug("- $pluginName: Group $name is undefined or has no members!");
        }
        foreach my $groupMember (@groupMembers) {
            if ( $name =~ /^.*\.(.*)$/ ) {
                processName($2);
            }
            else {
                processName($groupMember);
            }
        }
        $groups->{$name} = [@groupMembers];
    }
    $users->{$name} = TWiki::Func::readTopicText( $mainWeb, $user );
}

sub replaceGroups {
    my ( $name, $method, $methodUsers, $users, $groups ) = @_;
    return unless exists $groups->{$name};

    debug("- $pluginName: Group $name registered for method $method, expanding...");

    delete $methodUsers->{$name};
    foreach $member ( @{ $groups->{$name} } ) {
        if ( exists $groups->{$member} ) {
            replaceGroups( $member, $users, $groups );
        }
        else {
            $methodUsers->{$member} = \$users->{$member};
        }
    }
}

# =========================
sub afterSaveHandler {
    my ( $text, $topic, $web, $error ) = @_;

 # This handler is called by TWiki::Store::saveTopic just after the save action.

    debug("- ${pluginName}::afterSaveHandler( $_[2].$_[1] )");

    if ($error) {
        debug("- $pluginName: Unsuccessful save, not notifying...");
        return;
    }

    my @names;
    if ( $text =~ /^\t+\* Set IMMEDIATENOTIFY =(.*)\n[^\t]/sm ) {
        @names = split /[\s\r\n]*[,\s][\s\r\n]*/, $1;
    }

    my $notifyTopic = TWiki::Func::readTopicText( $web, "WebImmediateNotify" );
    my $mainWeb = TWiki::Func::getMainWebname();
    while ( $notifyTopic =~ /(\t+|(   )+)\* (?:\%MAINWEB\%|$mainWeb)\.([^\r\n]+)/go )
    {
        push @names, $3 if $3;
    }

    unless (@names) {
        debug("- $pluginName: No names registered for notification.");
        return;
    }

    my ( %users, %groups );
    foreach my $name (@names) {
        processName( $name, \%users, \%groups );
    }

    my ( %userTopics, %userMethods );
    foreach my $user ( keys %users ) {
        unless ( defined( $users{$user} ) && length( $users{$user} ) > 0 ) {
            warning("- $pluginName: User topic \"$mainWeb.$user\" not found!");
            next;
        }

        my @methodList = {};
        if ( $users{$user} =~ /(\t+|(   )+)\* Set IMMEDIATENOTIFYMETHOD = ([^\r\n]+)/ )
        {
            @methodList = split / *[, ] */, $3;
        }
        if (@methodList) {
            debug("- $pluginName: User $user: @methodList");
        }
        elsif ( !exists( $group{$member} ) ) {
            debug("- $pluginName: User $user chosen no methods, defaulting to SMTP.");
            @methodList = ("SMTP");
        }
        foreach my $method (@methodList) {
            $userMethods{$user}{$method} = 1;
        }
    }

    foreach my $method ( keys %methodHandlers ) {
        my %methodUsers =
          map { $userMethods{$user}{$method} ? ( $_, \$users{$_} ) : () }
          keys %users;
        my @userList =
          keys %methodUsers;  # save current key list, so we can modify the hash
        foreach my $user (@userList) {
            replaceGroups( $user, $method, \%methodUsers, \%users, \%groups );
        }
        debug( "- $pluginName: $method userlist " . join( " ", keys %methodUsers ) );
        if (%methodUsers) {
            &{ $methodHandlers{$method} }( \%methodUsers );
        }
    }
}

1;
