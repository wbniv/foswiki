# See bottom of file for license and copyright details
#
# Publish site (generate static HTML)
#
package Foswiki::Plugins::PublishPlugin;

use Foswiki;
use Foswiki::Func;
use Error qw( :try );

use strict;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev: 17708 $';

my $debug = 0;

$RELEASE = 'Foswiki-1';

sub initPlugin {
    unless ( defined $Foswiki::cfg{PublishPlugin}{Dir} ) {
        die "{PublishPlugin}{Dir} not defined; run install script";
    }
    unless( -d $Foswiki::cfg{PublishPlugin}{Dir}) {
        die "{PublishPlugin}{Dir} $Foswiki::cfg{PublishPlugin}{Dir} does not exist";
    }
    unless ( $Foswiki::cfg{PublishPlugin}{Dir} =~ m!/$!) {
        die "{PublishPlugin}{Dir} must terminate in a slash";
    }
    unless ($Foswiki::cfg{PublishPlugin}{URL}) {
        die "Can't publish because {PublishPlugin}{URL} was not set. Please notify your Wiki administrator";
    }
    if ( ! -d $Foswiki::cfg{PublishPlugin}{Dir} &&
           ! -e $Foswiki::cfg{PublishPlugin}{Dir}) {
        mkdir($Foswiki::cfg{PublishPlugin}{Dir}, 0777) ||
          die "Cannot mkdir {PublishPlugin}{Dir}";
    }
    unless (-d $Foswiki::cfg{PublishPlugin}{Dir} &&
              -w $Foswiki::cfg{PublishPlugin}{Dir}) {
        die "Can't publish because no useable {PublishPlugin}{Dir} was found. Please notify your Wiki administrator";
    }

    Foswiki::Func::registerRESTHandler('publish', \&_publishRESTHandler);
    Foswiki::Func::registerTagHandler(
        'PUBLISHERS_CONTROL_CENTRE',
        \&_publishControlCentre);
    return 1; # coupersetique
}

# Script function, linked from bin/publish
sub _publishRESTHandler {

    require Foswiki::Plugins::PublishPlugin::Publisher;
    die $@ if $@;

    my $publisher = new Foswiki::Plugins::PublishPlugin::Publisher(
       $Foswiki::Plugins::SESSION);

    my $query = Foswiki::Func::getCgiQuery();
    if (defined $query->param('control')) {
        # Control UI
        $publisher->control($query);
    } else {
        my $web = $query->param( 'web' ) ||
          $Foswiki::Plugins::SESSION->{webName};
        $query->delete('web');
        $web =~ m#([\w/.]*)#; # clean up and untaint

        $publisher->publishWeb($1);
    }
    $publisher->finish();
}

sub _display {
    my $msg = join('', @_);
    if (defined $Foswiki::Plugins::SESSION->{response} &&
          !Foswiki::Func::getContext()->{command_line}) {
        $Foswiki::Plugins::SESSION->{response}->print($msg);
    } else {
        print $msg;
    }
}

# Allow manipulation of $Foswiki::cfg{PublishPlugin}{Dir}
sub _publishControlCentre {

    my $query = TWiki::Func::getCgiQuery();

    # SMELL: check access to this interface!
    unless( Foswiki::Func::isAnAdmin()) {
        return CGI::span(
            {class=>'foswikiAlert'},
            "Only admins can access the control interface");
    }

    my $output = CGI::p(<<HERE);
<h1>Publishers Control Interface</h1>
This interface lets you perform basic management operations
on published output files and directories. Click on the name of the
output file to visit it.
HERE
    my $action = $query->param('action') || '';
    $query->delete('action'); # delete so we can redefine them
    my $file = $query->param('file');
    $query->delete('file');

    if ($action eq 'delete') {
        $file =~ m#([\w./\\]+)#; # untaint
        File::Path::rmtree("$Foswiki::cfg{PublishPlugin}{Dir}/$1");
        $output .= CGI::p("$1 deleted");
    }
    if (opendir(D, $Foswiki::cfg{PublishPlugin}{Dir})) {
        my @files = grep(!/^\./, readdir(D));
        if (scalar(@files)) {
            $output .= CGI::start_table();
            foreach my $file (@files) {
                my $link = "$Foswiki::cfg{PublishPlugin}{URL}/$file";
                $link = CGI::a({href => $link}, $file);
                my @cols = ( CGI::th($link) );
                my $delcol = CGI::start_form({ action => '',
                                               method=>'GET',
                                               name => $file });
                $delcol .= CGI::submit(
                    { type  => 'button',
                      name  => 'Delete'});
                $delcol .= CGI::hidden('file', $file);
                $delcol .= CGI::hidden('action', 'delete');
                $delcol .= CGI::hidden('control', '1');
                $delcol .= CGI::hidden('skin');
                $delcol .= CGI::end_form();
                push(@cols, $delcol);
                $output .= CGI::Tr({valign=>"baseline"},
                              join('', map {CGI::td($_)} @cols));
            }
            $output .= CGI::end_table();
        } else {
            $output .= "The output directory is currently empty";
        }
    } else {
        $output .= "Failed to open '$Foswiki::cfg{PublishPlugin}{Dir}': $!";
    }

    return $output;
}


1;
__END__
#
# Copyright (C) 2001 Motorola
# Copyright (C) 2001-2007 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2002, Eric Scouten
# Copyright (C) 2005-2008 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
# Removal of this notice in this or derivatives is forbidden.
