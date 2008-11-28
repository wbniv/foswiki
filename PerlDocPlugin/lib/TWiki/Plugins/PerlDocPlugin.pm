# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#   beforeSaveHandler    ( $text, $topic, $web )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

=begin twiki

---+ Testing TWiki formatting
| *simple* | *table* |
| cell 1 | cell 2 |
   * a bullet
   * again
      * with indent
---++ Level 2 heading
normal paragraph text with *bold* and =fixed font= text.

   1 numbered
   1 next

Last paragraph of this document block

=end twiki

=cut

# =========================
package TWiki::Plugins::PerlDocPlugin;

# =========================
use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev: 15566 $';

$RELEASE = 'Dakar';


# =========================
sub initPlugin {
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between PerlDocPlugin and Plugins.pm" );
        return 0;
    }

    if (TWiki::Func::getPreferencesFlag( 'PERLDOCPLUGIN_ENABLE' )) {
        TWiki::Func::registerTagHandler('PERLDOC', \&perlDocHandler);
        return 1;
    }

    return 0;
}

sub perlDocHandler {
    my( $session, $params, $topic, $web ) = @_;

    my $libName = $params->{_DEFAULT};
    my $format = lc( $params->{format} || '' );
    my $libFile = $libName;
    $libFile =~ s/\:\:/\//g;
    $libFile =~ s/[^a-zA-Z0-9_\/]//g;
    $libFile =~ /(.*)/;  # untaint
    $libFile = $1;
    return "%SYSTEMWEB%.PerlDocPlugin: Nothing to do, no module specified." unless( $libName );

    my $fileName = "";
    foreach( @INC ) {
        $filename = "$_/$libFile.pm";
        last if( -e $filename );
        $filename = "";
    }
    unless( $filename ) {
        my $path = join( ", ", @INC );
        return "%SYSTEMWEB%.PerlDocPlugin: Module =$libName= not found in lib path =$path=.";
    }

    my $rText = TWiki::Func::readFile( $filename );
    my $text = "";
    foreach( split( /\n\r?/, $rText ) ) {
        # convert tabs to spaces
        1 while( s/(.*?)(\t+)/' ' x (length($2) * 8 - length($1) % 8)/e );
        $text .= "$_\n";
    }

    # commented out for sequrity
    # unless( $format eq "raw" ) {
    #    $text = translatePod2TWiki( $text, ( $format eq "pod" ) );
    #}

    $text = translatePod2TWiki( $text, ( $format eq "pod" ) );

    unless( $text ) {
        return "%SYSTEMWEB%.PerlDocPlugin:  Module =$libName= has no documentation.";
    }

    if( $format =~ /(pod|twiki|raw|TML)/ ) {
        $text =~ s/&/&amp\;/go;
        $text =~ s/</&lt\;/go;
        $text =~ s/>/&gt\;/go;
        $text = "<pre>\n"
              . "<form><textarea readonly=\"readonly\" wrap=\"virtual\" rows=\"%EDITBOXHEIGHT%\" cols=\"%EDITBOXWIDTH%\">"
              . $text
              . "</textarea></form>\n"
              . "</pre>\n";
    }

    return $text;
}

# =========================
sub translatePod2TWiki
{
    my( $theText, $doReturnPod ) = @_;

    $theText =~ s/^.*?[\r\n](\=[a-zA-Z])/$1/s;  # cut code preceding doc
    $theText =~ s/^(.*[\r\n])\=cut.*?$/$1/s;    # cut code after last "=cut"
    $theText =~ s/([\r\n])\=cut.*?[\r\n](\=[a-zA-Z])/$1\n$2/gs; # cut code between "=cut" and "=any POD tag"
    return "" unless( $theText =~ /^\=/ );
    return $theText if( $doReturnPod );

    # format each paragraph
    my $mode = "";  # or "over", "item", "twiki", "hide"
    my $list = "";  # or "*", "1", "term"
    my $para = 0;
    my $tag = "";
    my $data = "";
    my $text = "";
    foreach( split( /\n\r?\n[\n\r]*/, $theText ) ) {
        if( $_ =~ /^\=([a-zA-Z0-9]+)\s*(.*)/s ) {
            $tag = $1;
            $data = $2 || "";
        } else {
            $tag = "";
            $data = "";
        }
        if( $mode eq "" ) {
            if( $tag =~ /^pod$/ ) {
                $mode = "twiki";
            } elsif( $tag =~ /^begin$/i ) {
                if( $data =~ /^(html|twiki|TML)/i ) {
                    $data =~ s@([\r\n])( +)@"$1" . "\t" x (length($2)/3)@ges;
                    $data =~ s/^(html|twiki)//i;
                    $text .= "$data\n\n";
                    $mode = "twiki";
                } else {
                    $mode = "hide";
                }
            } elsif( $tag =~ /^over$/i ) {
                $mode = "over";
            } elsif( $tag =~ /^head([1-4])$/i ) {
                $text .= "---" . "+" x $1 . renderInteriorSequences( " $data" ) . "\n";
            } elsif( $tag =~ /^for$/i ) {
                if( $data =~ /^(html|twiki|TML)/i ) {
                    $data =~ s@([\r\n])( +)@"$1" . "\t" x (length($2)/3)@ges;
                    $data =~ s/^(html|twiki)\s*//i;
                    $text .= "$data\n\n";
                }
            } elsif( $tag ) {
                # ignore other tags
            } elsif( $_ =~ /^ / ) {
                # preformatted paragraph
                unless( $text =~ s/<\/verbatim>\n+$/\n/s ) {
                    $text .= "<verbatim>\n";
                }
                $text .= "$_\n</verbatim>\n\n";
            } else {
                $text .= renderInteriorSequences( "$_" ) . "\n\n";
            }
        } elsif( $mode eq "twiki" || $mode eq 'TML' ) {
            if( $tag =~ /^end$/i ) {
                $mode = "";
            } elsif( $tag !~ /^pod$/i ) {
                s@(^|[\r\n])( +)@"$1" . "\t" x (length($2)/3)@ges;
                $text .= "$_\n\n";
            }
        } elsif( $mode eq "hide" ) {
            if( $tag =~ /^end$/i ) {
                $mode = "";
            }
        } elsif( $mode eq "over" ) {
            $mode = "item";
            if( $data =~ /^\*$/ ) {
                $list = "*";
            } elsif( $data =~ /^[0-9]+\.$/ ) {
                $list = "1";
            } else {
                $list = "$data";
            }
            $para = 0;
        } elsif( $mode eq "item" ) {
            if( $tag =~ /^back$/i ) {
                $mode = "";
            } elsif( $tag =~ /^item$/i ) {
                $list = "$data" unless( $list =~ /^[1\*]$/ );
                $para = 0;
            } else {
                s/[\n\r]+/ /gs;
                $para++;
                if( $para == 1 ) {
                    $first = 0;
                    if( $list =~ /^[1\*]$/ ) {
                        # ordered or unordered list
                        $text .= "\t$list " . renderInteriorSequences( "$_" ) . "\n";
                    } else {
                        # definition list
                        $list =~ s/ /&nbsp;/g;
                        $text .= renderInteriorSequences( "\t$list: $_" ) . "\n";
                    }
                } else {
                    $text .= "\t <p />\n" if( $para == 2 );
                    $text .= renderInteriorSequences( "\t $_" ) . "\n";
                    $text .= "\t <p />\n";
                }
            }
        }
    }

    return "<noautolink>\n$text\n</noautolink>\n";
}

sub renderInteriorSequences
{
    my( $theText ) = @_;

    $theText =~ s/[\n\r]+/ /gs;
    $theText =~ s/Z<>//g;
    $theText =~ s/E<([0-9]+)>/&#$1;/g;
    $theText =~ s/E<verbar>/\|/g;
    $theText =~ s/E<sol>/\//g;
    $theText =~ s/E<([a-zA-Z]+)>/&$1;/g;
    $theText =~ s/C<(.*?)>/ =$1=/gs;
    $theText =~ s/F<(.*?)>/ =$1=/gs;
    $theText =~ s/I<(.*?)>/ _$1_/gs;
    $theText =~ s/B<(.*?)>/ *$1*/gs;
    $theText =~ s/S<(.*?)>/<nobr>$1<\/nobr>/gs;
    $theText =~ s/X<(.*?)>//gs;
    $theText =~ s/L<([a-zA-Z\/\"\|]+)>/$1/g;
    return $theText;
}

# =========================

=pod

=head1 Testing POD formatting

text

=head2 Level 2 heading

text

=head3 Level 3 heading

text

=head4 Level 4 heading with C<fixed font> text

first paragraph

second paragraph. 
C<fixed font>, I<italic text>, B<bold text>, F<filename>,
S<non breaking text>, X<index entry is ignored>, emptyZ<>Stop

third paragraph with escapes: 
lt E<lt>, gt E<gt>, verbar E<verbar>, sol E<sol>, ouml E<ouml>,
181 E<181>.

fourth paragraph with link text "Perl Error Messages", name "perldiag":
L<Perl Error Messages|perldiag>

 preformatted text
  preformatted text
   preformatted text
  preformatted text
 preformatted text

=over 4

=item *

unordered bullet

=item *

second bullet

=back

normal paragraph

=over 4

=item 1.

numbered bullet

=item 2.

second bullet

=back

normal paragraph

=over 4

=item term 1

definition 1

=item term 2

definition 2

=back

testing =for twiki:

=for twiki ---++ heading in =for
and paragraph

testing =for unknown:

=for unknown text
and unknown paragraph

Next is HTML

=begin html

<p>This is <b>HTML</b> text (inside =begin html)</p>
<p>This is the second paragraph of HTML text</p>

=end html

normal paragraph

=begin text

This is normal text (inside =begin text)
Second line

=end text

normal paragraph. Next is hidden.

=begin unknown

This is unknown text (inside =begin unknown)

=end unknown

=cut

1;
