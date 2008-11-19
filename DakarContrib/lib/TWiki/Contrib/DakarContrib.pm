# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk
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
# As per the GPL, removal of this notice is prohibited.

# establish global vars 
BEGIN {
  $TWiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\x00-\x1f]/;

  unless( ( $TWiki::cfg{DetailedOS} = $^O ) ) {
      require Config;
      $TWiki::cfg{DetailedOS} = $Config::Config{'osname'};
  }
  $TWiki::cfg{OS} = 'UNIX';
  if ($TWiki::cfg{DetailedOS} =~ /darwin/i) { # MacOS X
      $TWiki::cfg{OS} = 'UNIX';
  } elsif ($TWiki::cfg{DetailedOS} =~ /Win/i) {
      $TWiki::cfg{OS} = 'WINDOWS';
  } elsif ($TWiki::cfg{DetailedOS} =~ /vms/i) {
      $TWiki::cfg{OS} = 'VMS';
  } elsif ($TWiki::cfg{DetailedOS} =~ /bsdos/i) {
      $TWiki::cfg{OS} = 'UNIX';
  } elsif ($TWiki::cfg{DetailedOS} =~ /dos/i) {
      $TWiki::cfg{OS} = 'DOS';
  } elsif ($TWiki::cfg{DetailedOS} =~ /^MacOS$/i) { # MacOS 9 or earlier
      $TWiki::cfg{OS} = 'MACINTOSH';
  } elsif ($TWiki::cfg{DetailedOS} =~ /os2/i) {
      $TWiki::cfg{OS} = 'OS2';
  }
}

=pod

---+ package TWiki::Sandbox
This object provides an interface to the outside world. All calls to
system functions, or handling of file names, should be brokered by
this object.

=cut

package TWiki::Sandbox;

use vars qw($VERSION $RELEASE);

use strict;
$VERSION = '$Rev$';
$RELEASE = '0.1';

#use Assert;
use Error qw( :try );
use File::Spec;


# TODO: Sandbox module should probably use custom 'die' handler so that
# output goes only to web server error log - otherwise it might give
# useful debugging information to someone developing an exploit.

=pod

---++ ClassMethod new( $os, $realOS )

Construct a new sandbox suitable for $os, setting
flags for platform features that help.  $realOS distinguishes
Perl variants on platforms such as Windows.

=cut

sub new {
    my ( $class, $os, $realOS ) = @_;
    my $this = bless( {}, $class );

    $os = $TWiki::cfg{OS} unless $os;
    $realOS = $TWiki::cfg{DetailedOS} unless $realOS;

    $this->{REAL_SAFE_PIPE_OPEN} = 1;     # supports open(FH, '-|")
    $this->{EMULATED_SAFE_PIPE_OPEN} = 1; # supports pipe() and fork()


    # filter the support based on what platforms are proven
    # not to work.
    #from the Activestate Docco this is _only_ defined on ActiveState Perl
    if( defined( &Win32::BuildNumber )) {	
#        if ( $isActivePerl and $] < 5.008 ) {
#           # Sven has not found either to work (yet?)
            $this->{REAL_SAFE_PIPE_OPEN} = 0;
            $this->{EMULATED_SAFE_PIPE_OPEN} = 0;
#        }
    }

    # 'Safe' means no need to filter in on this platform - check 
    # sandbox status at time of filtering
    $this->{SAFE} = ($this->{REAL_SAFE_PIPE_OPEN} ||
                       $this->{EMULATED_SAFE_PIPE_OPEN});

    # Shell quoting - shell used only on non-safe platforms
    if ($os eq 'UNIX' or ($os eq 'WINDOWS' and $realOS eq 'cygwin'  ) ) {
        $this->{CMDQUOTE} = '\'';
    } else {
        $this->{CMDQUOTE} = '"';
    }

    # Set to 1 to trace all command executions to STDERR
    $this->{TRACE} = 0;
    #$this->{TRACE} = 1;             # DEBUG

    return $this;
};


=pod

---++ StaticMethod untaintUnchecked ( $string ) -> $untainted

Untaints $string without any checks (dangerous).  If $string is
undefined, return undef.

The intent is to use this routine to be able to find all untainting
places using grep.

=cut

sub untaintUnchecked {
    my ( $string ) = @_;

    if ( defined( $string) && $string =~ /^(.*)$/ ) {
        return $1;
    }
    return $string;            # Can't happen.
}

=pod

---++ StaticMethod normalizeFileName ( $string ) -> $filename

STATIC Errors out if $string contains filtered characters.

The returned string is not tainted, but it may contain shell
metacharacters and even control characters.

=cut

sub normalizeFileName {
    my ($string) = @_;
    return '' unless $string;
    my $absolute = $string =~ /^\//;
    my @result;
    for my $component (split /\//, $string) {
        next unless $component;
        next if $component eq '.';
        if ($component eq '..') {
            throw Error::Simple( 'relative path in filename '.$string );
        } elsif ($component !~ /$TWiki::cfg{NameFilter}/) {
            # We need to untaint the string explicitly.
            # FIXME: This might be a Perl bug.
            push @result, untaintUnchecked( $component );
        } else {
            throw Error::Simple( 'illegal characters in file name component '.
                                   $component.' of filename '.$string );
        }
    }
    if (@result) {
        if ($absolute) {
            $result[0] = "/$result[0]";
        } elsif ($result[0] =~ /^-/) {
            $result[0] = "./$result[0]";
        }
        return join '/', @result;
    } else {
        return '/' if $absolute;
        throw Error::Simple( 'empty filename '.$string );
    }
}

# $template is split at whitespace, and '%VAR%' strings contained in it
# are replaced with $params{VAR}.  %params may consist of scalars and
# array references as values.  Array references are dereferenced and the
# array elements are inserted into the command line at the indicated
# point.
#
# '%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
# single character flag.  Permitted flags are
#   * U untaint without further checks -- dangerous,
#   * F normalize as file name,
#   * N generalized number,
#   * S simple, short string,
#   * D rcs format date

sub _buildCommandLine {
    my ($this, $template, %params) = @_;
    #ASSERT($this->isa( 'TWiki::Sandbox' )) if DEBUG;
    my @arguments;

    $template ||= '';

    for my $tmplarg (split /\s+/, $template) {
        next if $tmplarg eq ''; # ignore leading/trailing whitespace

        # Split single argument into its parts.  It may contain
        # multiple substitutions.

        my @tmplarg = $tmplarg =~ /([^%]+|%[^%]+%)/g;
        my @targs;
        for my $t (@tmplarg) {
            if ($t =~ /%(.*?)(|\|[A-Z])%/) {
                my ($p, $flag) = ($1, $2);
                if (! exists $params{$p}) {
                    throw Error::Simple( 'unknown parameter name '.$p );
                }
                my $type = ref $params{$p};
                my @params;
                if ($type eq '') {
                    @params = ($params{$p});
                } elsif ($type eq 'ARRAY') {
                    @params =  @{$params{$p}};
                } else {
                    throw Error::Simple( $type.' reference passed in '.$p );
                }

                for my $param (@params) {
                    unless ($flag) {
                        push @targs, $param;
                        next;
                    }
                    if ($flag =~ /U/) {
                        push @targs, untaintUnchecked($param);
                    } elsif ($flag =~ /F/) {
                        push @targs, normalizeFileName($param);
                    } elsif ($flag =~ /N/) {
                        # Generalized number.
                        if ( $param =~ /^([0-9A-Fa-f.x+\-]{0,30})$/ ) {
                            push @targs, $1;
                        } else {
                            throw Error::Simple( "invalid number argument '$param' $t" );
                        }
                    } elsif ($flag =~ /S/) {
                        # Harmless string.
                        if ( $param =~ /^([0-9A-Za-z.+_\-]{0,30})$/ ) {
                            push @targs, $1;
                        } else {
                            throw Error::Simple( "invalid string argument '$param' $t" );
                        }
                    } elsif ($flag =~ /D/) {
                        # RCS date.
                        if ( $param =~ m|^(\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$| ) {
                            push @targs, $1;
                        } else {
                            throw Error::Simple( "invalid date argument '$param' $t" );
                        }
                    } else {
                        throw Error::Simple( 'illegal flag in '.$t );
                    }
                }
            } else {
                push @targs, $t;
            }
        }

        # Recombine the argument if the template argument contained
        # multiple parts.

        if (@tmplarg == 1) {
            push @arguments, @targs;
        } else {
            push @arguments, join ('', @targs);
        }
    }

    return @arguments;
}

# Catch and redirect error reports from programs and argument processing,
# to avert the risk of exposing server paths to a hacker.
sub _safeDie {
    print STDERR $_[0];
    die "TWiki experienced a fatal error. Please check your webserver error logs for details."
}

=pod

---++ ObjectMethod sysCommand( $template, @params ) -> ( $data, $exit )

Invokes the program described by $template
and @params, and returns the output of the program and an exit code.
STDOUT is returned. STDERR is THROWN AWAY.

The caller has to ensure that the invoked program does not react in a
harmful way to the passed arguments.  sysCommand merely
ensures that the shell does not interpret any of the passed arguments.

=cut

# TODO: get emulated pipes or even backticks working on ActivePerl...

sub sysCommand {
    ##ASSERT(scalar(@_) % 2 == 0) if DEBUG;
    my ($this, $template, %params) = @_;
    #ASSERT($this->isa( 'TWiki::Sandbox')) if DEBUG;

    #local $SIG{__DIE__} = &_safeDie;

    my $data = '';          # Output
    my $handle;             # Holds filehandle to read from process
    my $exit = 0;           # Exit status of child process

    return '' unless $template;

    $template =~ /(^.*?)\s+(.*)$/;
    my $path = $1;
    my $pTmpl = $2;

    # Build argument list from template
    my @args = $this->_buildCommandLine( $pTmpl, %params );
    if ( $this->{REAL_SAFE_PIPE_OPEN} ) {
        # Real safe pipes, open from process directly - works
        # for most Unix/Linux Perl platforms and on Cygwin.  Based on
        # perlipc(1).

        # Note that there doesn't seem to be any way to redirect
        # STDERR when using safe pipes.

        my $pid = open($handle, '-|');

        throw Error::Simple( 'open of pipe failed: '.$! ) unless defined $pid;

        if ( $pid ) {
            # Parent - read data from process filehandle
            local $/ = undef; # set to read to EOF
            $data = <$handle>;
            close $handle;
            $exit = ( $? >> 8 );
        } else {
            # Child - run the command
	    #print STDERR "DakarContrib::sysCommand - executing $path @args\n";
            open (STDERR, '>'.File::Spec->devnull()) || die "Oh dear";
            exec( $path, @args ) ||
              throw Error::Simple( 'exec failed: '.$! );
            # can never get here
        }

    } elsif ( $this->{EMULATED_SAFE_PIPE_OPEN} ) {
        # Safe pipe emulation mostly on Windows platforms

        # Create pipe
        my $readHandle;
        my $writeHandle;

        pipe( $readHandle, $writeHandle ) ||
          throw Error::Simple( 'could not create pipe: '.$! );

        my $pid = fork();
        throw Error::Simple( 'fork() failed: '.$! ) unless defined( $pid );

        if ( $pid ) {
            # Parent - read data from process filehandle and remove newlines

            close( $writeHandle ) or die;

            local $/ = undef; # set to read to EOF
            $data = <$readHandle>;
            close( $readHandle );
            $pid = wait; # wait for child process so we can get exit status
            $exit = ( $? >> 8 );

        } else {
            # Child - run the command, stdout to pipe

            # close the read side of the pipe and streams inherited from parent
            close( $readHandle ) || die;

            # Despite documentation apparently to the contrary, closing
            # STDOUT first makes the subsequent open useless. So don't.
            open(STDOUT, ">&=".fileno( $writeHandle )) or die;

            open (STDERR, '>'.File::Spec->devnull());
            exec( $path, @args ) ||
              throw Error::Simple( 'exec failed: '.$! );
            # can never get here
        }

    } else {
        # No safe pipes available, use the shell as last resort (with
        # earlier filtering in unless administrator forced filtering out)

        # This really is last ditch. It would be amazing if a platform
        # had to rely on this. In fact, I question why we have it at all.
        # Sven: as of 11-July-2005 this is the only way to get ActiveStatePerl 
        # & IIS working (no cygwin)

        my $cq = $this->{CMDQUOTE};
        my $cmd = $path.' '.$cq.join($cq.' '.$cq, @args).$cq;
        open( OLDERR, '>&STDERR' ) || die "Can't steal STDERR: $!";
        open( STDERR, '>'.File::Spec->devnull());
        $data = `$cmd`;
        # restore STDERR
        close( STDERR );
        open( STDERR, '>&OLDERR' ) || die "Can't restore STDERR: $!";
        close(OLDERR);
        $exit = ( $? >> 8 );
    }

    if( $this->{TRACE} ) {
        my $cq = $this->{CMDQUOTE};
        my $cmd = $path.' '.$cq.join($cq.' '.$cq, @args).$cq;
        print STDERR $cmd.' -> '.$data."\n";
    }
    return ( $data, $exit );
}

1;

