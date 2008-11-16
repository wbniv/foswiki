# See bottom of file for license and copyright info
#
# Virtual file system layered over a NextWiki data store.
# As far as possible this interface only uses the published methods of
# TWiki::Func.
#
# Return values are based on the return values from Filesys::Virtual::Plain
#
# Author: Crawford Currie http://c-dot.co.uk
#
package Filesys::Virtual::NextWiki;
# Base class not strictly needed
use base 'Filesys::Virtual';

use strict;

use File::Path;
use POSIX ':errno_h';

use TWiki::Plugins; # for $SESSION
use TWiki::Func;    # for API

our $VERSION = '1.0';
our $TOPIC_EXT = '.txt';
our $FILES_EXT = '_files';

=pod

=head1 NAME

Filesys::Virtual::NextWiki - A virtual filesystem for NextWiki (and TWiki)

=head1 SYNOPSIS

	use Filesys::Virtual::NextWiki;

	my $fs = Filesys::Virtual::NextWiki->new();

	print foreach ($fs->list('/Sandbox'));

=head1 DESCRIPTION

This module is used by other modules to provide a pluggable filesystem
that sites on top of a NextWiki (or TWiki) data store.

=head1 CONSTRUCTOR

=head2 new(\%args)

You may pass the 'location' in the \%args. This is an optional prefix
that will be be expected on all paths (which must be absolute).

=head1 METHODS

=cut

sub new {
    my $class = shift;
    my $args = shift;
    # root_path is the location
    # cwd is the full path to the resource (ignore)

    if (!$TWiki::Plugins::SESSION) {
        new TWiki(undef, undef, { dav => 1 }); # auth?
        #print STDERR "Created new session: $args->{location}\n";
    } else {
        #print STDERR "Reused same session\n";
    }
    my $this = bless({
        path => '/',
        session => $TWiki::Plugins::SESSION,
    }, $class);
	foreach my $field (keys %$args) {
		if ($this->can($field)) {
            $this->$field($args->{$field});
        }
	}
    return $this;
}

# Break a resource into its component parts, web, topic, attachment.
# The return value is an array which may have up to 3 entries:
# [0] is always the full web path name
# [1] is always the topic name with no suffix ($TOPIC_EXT/$FILES_EXT removed)
# [2] is the attachment name
# if the array is empty, that indicates the root (/)
sub _parseResource {
    my ($this, $resource) = @_;
    if (defined $this->{location} && $resource =~ s/^$this->{location}//) {
        # Absolute path; must be, cos it has a location
    } elsif ($resource !~ /^\//) {
        # relative path
        $resource = $this->{path}.'/'.$resource;
    }
    $resource =~ s/\/\/+/\//g; # normalise // -> /
    $resource =~ s/^\/+//; # remove leading /
    # Resolve the path into it's components
    my @path;
    foreach (split(/\//, $resource)) {
        if ($_ eq '..') {
            pop(@path) if ($#path);
        } elsif ($_ eq '.') {
            next;
        } elsif ($_ eq '~')	{
            @path = ( $TWiki::cfg{UsersWebName} );
        } else {
            push(@path, $_);
		}
    }
    # Greedily descend through webs to $TOPIC_EXT or $FILES_EXT
    my $web = shift(@path);
    while (scalar(@path) && $path[0] !~ /($TOPIC_EXT|$FILES_EXT)$/o) {
        $web .= '/'.shift(@path);
    }
    my @result = ($web);
    return @result unless scalar(@path);
    push(@result, shift(@path)); # topic$TOPIC_EXT or topic$FILES_EXT
    push(@result, shift(@path)) if scalar(@path); # attachment
    die "Bad path! ".join('/',@path) if scalar(@path);
    return @result;
}

# Many functions have to have five versions for different points in the
# store hierarchy. This are indicated by the prefixes:
# _R_ - root (/)
# _W_ - web
# _T_ - topic ($TOPIC_EXT file)
# _D_ - topic (attachments dir)
# _A_ - attachment
# This function determines which level is applicable from the path, and
# redirects to the appropriate version.
sub _dispatch {
    my $this = shift;
    my $function = shift;
    my $resource = shift;
    my @path = $this->_parseResource($resource);
    my $topic_type;
    if (scalar(@path) > 1) {
        if ($path[1] =~ s/$TOPIC_EXT$//) {
            $topic_type = 'T';
        } elsif ($path[1] =~ s/$FILES_EXT$//) {
            $topic_type = 'D';
        } else {
            die "Internal error";
        }
    }
    my $type = 'R';
    if ($path[2]) {
        $type = 'A';
    } elsif ($path[1]) {
        $type = $topic_type;
    } elsif ($path[0]) {
        $type = 'W';
    }
    $function = "_${type}_$function";
    #print "Call $function for $resource\n";
    return $this->$function(@path, @_);
}

# test if a topic has an attachments dir
sub _hasAttachments {
    my ($web, $topic) = @_;
    # SMELL: violating Store encapsulation
    return -d "$TWiki::cfg{PubDir}/$web/$topic";
}

# Test if the current user has access to the given resource
sub _haveAccess {
    my ($type, $web, $topic) = @_;
    if (!$web || $web eq '/') {
        $type = "ROOT$type";
        $web = undef;
    }
    return TWiki::Func::checkAccessPermission(
        $type, $TWiki::Plugins::SESSION->{user}, undef, $topic, $web, undef);
}

# Get the parent path of a path
sub _parent {
    my $web = shift;
    if ($web =~ /(.*)\/[^\/]*\/*$/) {
        return $1 || '/';
    } else {
        return '/';
    }
}

# Work out a file mode for the given resource
sub _getMode {
    my ($web, $topic) = @_;
    my $mode = 0; # ----------

    if (!$topic) {
        if (!$web || TWiki::Func::webExists($web)) {
            # No access unless web exists or root
            $mode |= 01111; # d--x--x--x
            if (_haveAccess('VIEW', $web)) {
                $mode |= 0444; # -r--r--r--
                # No change without view
                if (_haveAccess('CHANGE', $web)) {
                    $mode |= 0222; # --w--w--w-
                }
            }
        }
    } elsif (_haveAccess('VIEW', $web, $topic)) {
        $mode |= 0444; # -r--r--r--
        # No change without view
        if (_haveAccess('CHANGE', $web, $topic)) {
            $mode |= 0222; # --w--w--w-
        }
    }
    # print STDERR "MODE /".($web||'')."/".($topic||'')."=$mode\n";
    return $mode;
}

sub cwd {
    my ($this, $path) = @_;
    # Ignore this. Use chdir to navigate.
}

=pod

=head2 root_path($path)

Get or set the root path. This is the location that should be on the front
of all paths passed to methods of this class.

For example, if you define a WebDAV handler that works on the location
/dav, then this path will be set to /dav. Requests to files under that
location will have the /dav prefix removed before processing.

=cut

sub root_path {
    my ($this, $path) = @_;
    if (defined $path) {
        $this->{location} = $path;
    }
    return $this->{location};
}

# Not supported for NextWiki
sub chmod {
    $! = POSIX::EPERM;
    return 0;
}

=pod

=head2 modtime($file)

Gets the modification time of a file in YYYYMMDDHHMMSS format.

=cut

sub modtime {
    my $this = shift;
    my @stat = $this->stat(@_);
    return (0, '') unless scalar(@stat);
	my ($sec, $min, $hr, $dd, $mm, $yy, $wd, $yd, $isdst) =
      localtime($stat[9]);
    $yy += 1900;
    $mm++;
	return (1, "$yy$mm$dd$hr$min$sec");
}

=pod

=head2 size($file)

Gets the size of a file in bytes.

=cut

sub size {
    my $this = shift;
    my @stat = $this->stat(@_);
    return $stat[7];
}

=pod

=head2 delete($file)

Deletes a file, returns 1 or 0 on success or failure. ($! is set)

=cut

sub delete {
    my ($this, $file) = @_;
    return $this->_dispatch('delete', $file);
}

sub _R_delete {
    $! = POSIX::EPERM;
    return 0;
}

sub _A_delete {
    my ($this, $web, $topic, $attachment) = @_;
    unless (TWiki::Func::attachmentExists($web, $topic, $attachment)) {
        $! = POSIX::ENOENT;
        return 0;
    }
    if (!_haveAccess('CHANGE', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    my $n = '';
    while (TWiki::Func::attachmentExists(
        $TWiki::cfg{TrashWebName}, $topic, $attachment.$n)) {
        $n++;
    }
    my $newAttachment = $attachment.$n;
    eval {
        TWiki::Func::moveAttachment(
            $web, $topic, $attachment,
            $TWiki::cfg{TrashWebName}, 'TrashAttachment', $newAttachment );
    };
    if ($@) {
        $! = $@;
        return 0;
    }
    return 1;
}

sub _T_delete {
    my ($this, $web, $topic) = @_;
    if (!_haveAccess('CHANGE', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    my $n = '';
    while (TWiki::Func::topicExists(
        $TWiki::cfg{TrashWebName}, $topic.$n)) {
        $n++;
    }
    my $newTopic = $topic.$n;
    eval {
        TWiki::Func::moveTopic(
            $web, $topic, $TWiki::cfg{TrashWebName}, $newTopic );
    };
    if ($@) {
        $! = $@;
        return 0;
    }
    return 1;
}

sub _D_delete {
    my ($this, $web, $topic) = @_;
    # Use rmdir
    $! = POSIX::EPERM;
    return 0;
}

sub _W_delete {
    my ($this, $web) = @_;
    # Use rmdir
    $! = POSIX::EPERM;
    return 0;
}

=pod

=head2 chdir($dir)

Changes the cwd.
Returns undef on failure or the new path on success.

=cut

sub chdir {
    my $this = shift;
    return $this->_dispatch('chdir', @_);
}

sub _R_chdir {
    my ($this) = @_;
    $this->{path} = '';
    return $this->{path}
}

sub _W_chdir {
    my ($this, $web) = @_;
    if (TWiki::Func::webExists($web)) {
        $this->{path} = $web;
        return $this->{path}
    }
    return undef;
}

sub _T_chdir {
    my ($this, $web, $topic) = @_;
}

sub _D_chdir {
    my ($this, $web, $topic) = @_;
    if (_hasAttachments($web, $topic)) {
        $this->{path} = "$web/$topic";
        return $this->{path}
    }
    return undef;
}

sub _A_chdir { return undef; }

=pod

=head2 mkdir($dir)

Creates a 'directory' (web of attachments dir). Returns 0 (and sets $!)
on failure. Returns 1 otherwise (directory created or already exists)

=cut

sub mkdir {
    my $this = shift;
    return $this->_dispatch('mkdir', @_);
}

sub _R_mkdir {
    # Can't mkdir the root dir
    $! = POSIX::EPERM;
    return 0;
}

sub _A_mkdir {
    # Can't mkdir in an attachments dir
    $! = POSIX::EPERM;
    return 0;
}

# Create an attachments dir.
sub _D_mkdir {
    my ($this, $web, $topic) = @_;
    if (_hasAttachments($web, $topic)) {
        return 1;
    }
    if (!_haveAccess('CHANGE', _parent($web), $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # Create an attachments dir.
    # SMELL: violating store encapsulation
    return File::Path::mkpath(
        "$TWiki::cfg{PubDir}/$web/$topic",
        { mode => $TWiki::cfg{RCS}{dirPermission} });
}

sub _T_mkdir {
    # Can't mkdir a topic name
    $! = POSIX::EPERM;
    return 0;
}

sub _W_mkdir {
    my ($this, $web) = @_;
    # Called on an existing web?
    if (TWiki::Func::webExists($web)) {
        return 1;
    }
    # Check change access on parent
    if (!_haveAccess('CHANGE', _parent($web))) {
        $! = POSIX::EACCES;
        return 0;
    }
    my $result = 0;
    eval {
        TWiki::Func::createWeb($web, "_default");
    };
    if ($@) {
        $! = $@;
        return 0;
    }
    return 1;
}

=pod

=head2 rmdir($dir)

Deletes a directory or file if -d test fails. Returns 1 on success or 0 on
failure (sets $!).

=cut

sub rmdir {
    my $this = shift;
    return $this->_dispatch('rmdir', @_);
}

sub _R_rmdir {
    $! = POSIX::EPERM;
    return 0;
}

sub _W_rmdir {
    my ($this, $web) = @_;
    unless (TWiki::Func::webExists($web)) {
        $! = POSIX::ENOENT;
        return 0;
    }
    if (!_haveAccess('CHANGE', $web)) {
        $! = POSIX::EACCES;
        return undef;
    }
    if (!_haveAccess('CHANGE', $TWiki::cfg{TrashWebName})) {
        $! = POSIX::EACCES;
        return undef;
    }
    my @topics = TWiki::Func::getTopicList($web);
    if (scalar(@topics) > 1) {
        # non-empty
        $! = POSIX::ENOTEMPTY;
        return 0;
    }
    my $n = '';
    while (TWiki::Func::webExists("$TWiki::cfg{TrashWebName}/$web$n")) {
        $n++;
    }
    my $newWeb = "$TWiki::cfg{TrashWebName}/$web$n";
    eval {
        TWiki::Func::moveWeb($web, $newWeb);
    };
    if ($@) {
        $! = $@;
        return 0;
    } else {
        return 1;
    }
}

sub _A_rmdir {
    my ($this, $web, $topic, $attachment) = @_;
    return $this->_A_delete($web, $topic, $attachment);
}

sub _T_rmdir {
    my ($this, $web, $topic) = @_;
    return $this->_T_delete($web, $topic);
}

sub _D_rmdir {
    my ($this, $web, $topic) = @_;
    if (!_haveAccess('CHANGE', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # SMELL: violate store encapsulation by deleting the empty directory
    return CORE::rmdir("$TWiki::cfg{PubDir}/$web/$topic");
}

=pod

=head2 list($dir)

Returns an array of the files in a directory. Returns undef and sets $!
on failure.

=cut

sub list {
    my $this = shift;
    my $list = $this->_dispatch('list', @_);
    return undef unless $list;
    return sort @$list;
}

sub _R_list {
    my ($this, $web) = @_;
    my @list = TWiki::Func::getListOfWebs( 'user,public' );
    push(@list, '.');
    return \@list;
}

sub _W_list {
    my ($this, $web) = @_;
    my @list;
    if (!_haveAccess('VIEW', $web)) {
        $! = POSIX::EACCES;
        return \@list;
    }
    my @tops;
    foreach my $f (TWiki::Func::getTopicList( $web )) {
        if (_hasAttachments( $web, $f )) {
            push( @tops, "$f$FILES_EXT" );
        }
        push(@tops, "$f$TOPIC_EXT");
    }
    # SMELL: violating Store encapsulation (no other way to get subwebs!
    @list = ('.', '..', @tops,
             $TWiki::Plugins::SESSION->{store}->getListOfWebs(
                 'public,user', $web));
    return \@list;
}

sub _D_list {
    my ($this, $web, $topic) = @_;
    if (!_haveAccess('VIEW', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # list attachments
    # SMELL: violating Store encapsulation
    my $dir = "$TWiki::cfg{PubDir}/$web/$topic";
    my @list;
    if (opendir(D, "$dir")) {
        foreach my $e (grep { !/,v$/ } readdir(D)) {
            $e =~ /^(.*)$/;
            push(@list, $1);
        }
    }
    return \@list;
}

sub _T_list {
    my ($this, $web, $topic) = @_;
    return [ "$topic$TOPIC_EXT" ];
}

sub _A_list {
    my ($this, $web, $topic, $attachment) = @_;
    return [ $attachment ];
}

# Returns an array of the files in ls format.
sub list_details {
    my $this = shift;
    # TODO: do this properly (if necessary)
    return $this->ls(@_);
}

=pod

=head2 stat($file)

Does a normal stat() on a file or directory

=cut

# SMELL: this is a major violation of store encapsulation. Should the
# TWiki store attempt to provide this sort of info? Really, Filesys::Virtual
# should be a low-level interface provided by that store.
sub stat {
    my $this = shift;
    return $this->_dispatch('stat', @_);
}

sub _R_stat {
    my ($this) = @_;
    return () unless -e $TWiki::cfg{DataDir};
    my @stat = CORE::stat($TWiki::cfg{DataDir});
    $stat[2] = _getMode();
    return @stat;
}

sub _W_stat {
    my ($this, $web) = @_;
    return () unless -e "$TWiki::cfg{DataDir}/$web";
    my @stat = CORE::stat("$TWiki::cfg{DataDir}/$web");
    $stat[2] = _getMode($web);
    return @stat;
}

sub _D_stat {
    my ($this, $web, $topic) = @_;
    return () unless -e "$TWiki::cfg{PubDir}/$web/$topic";
    my @stat = CORE::stat("$TWiki::cfg{PubDir}/$web/$topic");
    $stat[2] = _getMode($web, $topic) | 01111;
    return @stat;
}

sub _T_stat {
    my ($this, $web, $topic) = @_;
    return () unless -e "$TWiki::cfg{DataDir}/$web/$topic.txt";
    my @stat = CORE::stat("$TWiki::cfg{DataDir}/$web/$topic.txt");
    $stat[2] = _getMode($web, $topic);
    return @stat;
}

sub _A_stat {
    my ($this, $web, $topic, $attachment) = @_;
    return () unless -e "$TWiki::cfg{PubDir}/$web/$topic/$attachment";
    my @stat = CORE::stat("$TWiki::cfg{PubDir}/$web/$topic/$attachment");
    $stat[2] = _getMode($web, $topic);
    return @stat;
}

=pod

=head2 test($test,$file)

Perform a perl type test on a file and returns the results. Some of the tests
don't make sense on NextWiki database data; these will return false.

For example to perform a -d on a directory.

	$self->test('d','/testdir');

-r  File is readable by effective uid/gid
-w  File is writable by effective uid/gid.
-x  File is executable by effective uid/gid.
-o  File is owned by effective uid.

-R  File is readable by real uid/gid.
-W  File is writable by real uid/gid.
-X  File is executable by real uid/gid.
-O  File is owned by real uid.

-e  File exists.
-z  File has zero size.
-s  File has nonzero size (returns size).

-f  File is a plain file.
-d  File is a directory.
-l  File is a symbolic link.
-p  File is a named pipe (FIFO), or Filehandle is a pipe.
-S  File is a socket.
-b  File is a block special file.
-c  File is a character special file.
-t  Filehandle is opened to a tty.

-u  File has setuid bit set.
-g  File has setgid bit set.
-k  File has sticky bit set.

-T  File is a text file.
-B  File is a binary file (opposite of -T).

-M  Age of file in days when script started.
-A  Same for access time.
-C  Same for inode change time.

=cut

sub test {
    my ($this, $mode, $file) = @_;
    return $this->_dispatch('test', $file, $mode);
}

sub _R_test {
    my ($this, $undef, $type) = @_;
    if ($type =~/r/i) {
        # File is readable by effective/real uid/gid.
        return 1; # No way to limit this, AFAIK
    }
    elsif ($type =~ /w/i) {
        # File is writable by effective/real uid/gid.
        return _haveAccess('CHANGE');
    }
    elsif ($type =~ /[de]/) {
        return 1;
    }
    else {
        # SMELL: violating Store encapsulation
        return eval "-$type '$TWiki::cfg{DataDir}'";
    }
}

sub _A_test {
    my ($this, $web, $topic, $attachment, $type) = @_;
    if ($type =~/r/i) {
        # File is readable by effective/real uid/gid.
        return _haveAccess('VIEW', $web, $topic);
    }
    elsif ($type =~ /w/i) {
        # File is writable by effective/real uid/gid.
        return _haveAccess('CHANGE', $web, $topic);
    }
    elsif ($type =~ /x/i) {
        # File is executable by effective/real uid/gid.
        return 0;
    }
    elsif ($type =~ /o/i) {
        # File is owned by effective/real uid.
        return 1; # might as well be, for all the difference it makes
    }
    elsif ($type eq 'e') {
        # File exists.
        return TWiki::Func::attachmentExists( $web, $topic, $attachment );
    }
    elsif ($type eq 'f') {
        # File is a plain file (always)
        return 1;
    }
    elsif ($type eq 'd') {
        # File is a directory (never)
        return 0;
    }

    # All other ops, kick down to the filesystem
    # SMELL: violating Store encapsulation
    # lpSbctugkTBzsMAC
    my $file = "$TWiki::cfg{PubDir}/$web/$topic/$attachment";
    return eval "-$type $file";
}

sub _D_test {
    my ($this, $web, $topic, $type) = @_;
    if ($type =~/r/i) {
        # File is readable by effective/real uid/gid.
        return _haveAccess('VIEW', $web, $topic);
    }
    elsif ($type =~ /w/i) {
        # File is writable by effective/real uid/gid.
        return _haveAccess('CHANGE', $web, $topic);
    }
    elsif ($type =~ /x/i) {
        # File is executable by effective/real uid/gid.
        return 1;
    }
    elsif ($type =~ /o/i) {
        # File is owned by effective/real uid.
        return 1; # might as well be, for all the difference it makes
    }
    elsif ($type eq 'e') {
        # File exists.
        # Referring to the attachments subdir
        return _hasAttachments($web, $topic);
    }
    elsif ($type eq 'f') {
        # File is a plain file.
        return 0;
    }
    elsif ($type eq 'd') {
        # File is a directory.
        return 1;
    }

    # All other ops, kick down to the filesystem
    # SMELL: violating Store encapsulation
    # lpSbctugkTBzsMAC
    return eval "-$type $TWiki::cfg{PubDir}/$web/$topic";
}

sub _T_test {
    my ($this, $web, $topic, $type) = @_;
    if ($type =~/r/i) {
        # File is readable by effective/real uid/gid.
        return _haveAccess('VIEW', $web, $topic);
    }
    elsif ($type =~ /w/i) {
        # File is writable by effective/real uid/gid.
        return _haveAccess('CHANGE', $web, $topic);
    }
    elsif ($type =~ /x/i) {
        # File is executable by effective/real uid/gid.
        return 0;
    }
    elsif ($type =~ /o/i) {
        # File is owned by effective/real uid.
        return 1; # might as well be, for all the difference it makes
    }
    elsif ($type eq 'e') {
        # File exists.
        return TWiki::Func::topicExists( $web, $topic );
    }
    elsif ($type eq 'f') {
        # File is a plain file.
        return 1;
    }
    elsif ($type eq 'd') {
        # File is a directory.
        return 0;
    }

    # All other ops, kick down to the filesystem
    # SMELL: violating Store encapsulation
    # lpSbctugkTBzsMAC
    return eval "-$type $TWiki::cfg{DataDir}/$web/$topic.txt";
}

sub _W_test {
    my ($this, $web, $type) = @_;
    if ($type =~/r/i) {
        # File is readable by effective/real uid/gid.
        return _haveAccess('VIEW', $web);
    }
    elsif ($type =~ /w/i) {
        # File is writable by effective/real uid/gid.
        return _haveAccess('CHANGE', $web);
    }
    elsif ($type =~ /x/i) {
        # File is executable by effective/real uid/gid.
        return 1; # it's a dir
    }
    elsif ($type =~ /o/i) {
        # File is owned by effective/real uid.
        return 1; # might as well be, for all the difference it makes
    }
    elsif ($type eq 'e') {
        # File exists.
        return TWiki::Func::webExists( $web );
    }
    elsif ($type eq 'f') {
        # File is a plain file.
        return 0;
    }
    elsif ($type eq 'd') {
        # File is a directory.
        return 1;
    }

    # All other ops, kick down to the filesystem
    # SMELL: violating Store encapsulation
    # lpSbctugkTBzsMAC
    my $file = "$TWiki::cfg{DataDir}/$web";
    return eval "-$type $file";
}

=pod

=head2 open_read($file,[params])

Opens a file with L<IO::File>. Params are passed to open() of IO::File.
It returns the file handle on success or undef on failure. See L<IO::File>'s
open method.

When used to open topics, the content read from the file contains all the
meta-data associated with the topic.

=cut

sub open_read {
    my ($this, $file, @params) = @_;
    return $this->_dispatch('open_read', $file, @params);
}

sub _R_open_read { $!= POSIX::EPERM; return 0; }

sub _W_open_read {  $!= POSIX::EPERM; return 0; }

sub _D_open_read {  $!= POSIX::EPERM; return 0; }

sub _T_open_read {
    my ($this, $web, $topic) = @_;
    if (!_haveAccess('VIEW', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # SMELL: violating Store encapsulation
    my $fin = "$TWiki::cfg{DataDir}/$web/$topic.txt";
	return IO::File->new($fin);
}

sub _A_open_read {
    my ($this, $web, $topic, $attachment) = @_;
    if (!_haveAccess('VIEW', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # SMELL: violating Store encapsulation
    my $fin = "$TWiki::cfg{PubDir}/$web/$topic/$attachment";
	return IO::File->new($fin);
}

=pod

=head2 close_read($fh)

Performs a $fh->close() on a read handle

=cut

sub close_read {
    my ($this, $fh) = @_;
	return $fh->close();
}

=pod

=head2 open_write($fh, $append)

Performs an $fh->open(">$file") or $fh->open(">>$file") if $append is defined.
Returns the filehandle on success or undef on failure.

=cut

sub open_write {
    my ($this, $fh, $append) = @_;
    return $this->_dispatch('open_write', $fh, $append);
}

sub _R_open_write {  $!= POSIX::EPERM; return 0; }

sub _W_open_write {  $!= POSIX::EPERM; return 0; }

sub _D_open_write {  $!= POSIX::EPERM; return 0; }

sub _T_open_write {
    my ($this, $web, $topic, $append) = @_;
    if (!_haveAccess('CHANGE', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # SMELL: violating Store encapsulation
	my $o = (defined($append)) ? '>>' : '>';
    my $fin = "$TWiki::cfg{DataDir}/$web/$topic.txt";
	return new IO::File($o.$fin);
}

sub _A_open_write {
    my ($this, $web, $topic, $attachment, $append) = @_;
    if (!_haveAccess('CHANGE', $web, $topic)) {
        $! = POSIX::EACCES;
        return undef;
    }
    # SMELL: violating Store encapsulation
	my $o = (defined($append)) ? '>>' : '>';
    my $fin = "$TWiki::cfg{PubDir}/$web/$topic/$attachment";
	return new IO::File($o.$fin);
}

=pod

=head2 close_write($fh)

Performs a $fh->close() on a write handle

=cut

sub close_write {
    my ($this, $fh) = @_;
    $fh->close();
	return 1;
}

=pod

=head2 seek($fh, $pos, $wence)

Performs a $fh->seek($pos, $wence). See L<IO::Seekable>.

=cut

sub seek {
    my ($this, $fh, $pos, $wence) = @_;
	return $fh->seek($pos, $wence);
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) NextWiki Contributors http://nextwiki.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

Do not remove this notice from this or any derivatives.
