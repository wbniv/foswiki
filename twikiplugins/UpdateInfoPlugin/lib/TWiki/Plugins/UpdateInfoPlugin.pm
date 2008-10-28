#
#      TWiki UpdateInfo Plugin
#
#      Written by Chris Huebsch chu@informatik.tu-chemnitz.de
#
# 31-Mar-2005:   SteffenPoulsen
#                  - Updated plugin to be I18N-aware
#  2-Apr-2005:   SteffenPoulsen
#                  - Support for more TWikiML link syntaxes, cleaned up code, touched documentation
#  4-Apr-2005:   SteffenPoulsen
#                  - Support for _even more_ TWikiML link syntaxes (i.e. "-" now allowed in WikiWord)
#  6-Apr-2005:   SteffenPoulsen (patch by DieterWeber)
#                  - Fetch default "days" and "version" variables from TWiki variables.
#                  - Search web/user/topic preferences first, and then in the plugin if we can't find it
# 10-Jan-2006:   SteffenPoulsen
#                  - Dakar compatibility
# 20-Apr-2006:   SteffenPoulsen
#                  - Cairo+Dakar compatibility
# 26-Jul-2006:   SteffenPoulsen
#                  - Updated to use default new and updated icons (from TWiki.TWikiDocGraphics)

package TWiki::Plugins::UpdateInfoPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $plural2SingularEnabled
  $wnre
  $wwre
  $manre
  $abbre
  $smanre
  $days
  $version
);

# This should always be $Rev: 11199 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11199 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching
    if ( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between UpdateInfoPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences
    $debug = &TWiki::Func::getPreferencesFlag("UPDATEINFOPLUGIN_DEBUG");

    $days = &TWiki::Func::getPreferencesValue("UPDATEINFODAYS")
      || &TWiki::Func::getPreferencesValue("UPDATEINFOPLUGIN_DAYS")
      || "5";

    $version = &TWiki::Func::getPreferencesValue("UPDATEINFOVERSION")
      || &TWiki::Func::getPreferencesValue("UPDATEINFOPLUGIN_VERSION")
      || "1.1";

    $wnre   = TWiki::Func::getRegularExpression('webNameRegex');
    $wwre   = TWiki::Func::getRegularExpression('wikiWordRegex');
    $manre  = TWiki::Func::getRegularExpression('mixedAlphaNum');
    $abbre  = TWiki::Func::getRegularExpression('abbrevRegex');
    $smanre = TWiki::Func::getRegularExpression('singleMixedAlphaNumRegex');

    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    TWiki::Func::writeDebug(
        '- $TWiki::cfg{UseLocale}: ' . "$TWiki::cfg{UseLocale}" )
      if $debug;

    # Plugin correctly initialized
    return 1;
}

sub update_info {
    my ( $defweb, $wikiword, $opts ) = @_;
    $opts ||= '';    # pre-define $opts to prevent error messages

    # save old link (preserve [[-style links)
    my $oldwikiword = $wikiword;

    # clear [[-style formatting for [[WikiWordAsWebName.WikiWord][link text]] 
    # and [[WikiWord][link text]]
    $wikiword =~ s/\[\[($wnre\.$wwre|$wwre)\]\[.*?\]\]/$1/o;

    ( $web, $topic ) = split( /\./, $wikiword );
    if ( !$topic ) {
        $topic = $web;
        $web   = $defweb;
    }

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $topic =~ s/^(.)/\U$1/o;
    $topic =~ s/\s($smanre)/\U$1/go;
    $topic =~ s/\[\[($smanre)(.*?)\]\]/\u$1$2/o;

    my $match = 0;

    if ( $TWiki::Plugins::VERSION < 1.1 ) {

        # Cairo

        ( $meta, $dummy ) = TWiki::Store::readTopMeta( $web, $topic );
        if ($meta) {
            $match = 1;

            $opts =~ s/{(.*?)}/$1/geo;

            $params{"days"}    = "$days";
            $params{"version"} = "$version";

            foreach $param ( split( / /, $opts ) ) {
                ( $key, $val ) = split( /=/, $param );
                $val =~ tr [\"] [ ];
                $params{$key} = $val;
            }

            %info = $meta->findOne("TOPICINFO");
        }
    }
    else {

        # Dakar
        ( $meta, $dummy ) = TWiki::Func::readTopic( $web, $topic );
        if ($meta) {
            $match = 1;

            $opts =~ s/{(.*?)}/$1/geo;

            $params{"days"}    = "$days";
            $params{"version"} = "$version";

            foreach $param ( split( / /, $opts ) ) {
                ( $key, $val ) = split( /=/, $param );
                $val =~ tr ["] [ ];
                $params{$key} = $val;
            }

            if ( defined(&TWiki::Meta::findOne) ) {
                %info = $meta->findOne("TOPICINFO");
            }
            else {
                my $r = $meta->get("TOPICINFO");
                return '' unless $r;
                %info = %$r;
            }
        }
    }

    if ($match) {
        $updated =
          ( ( time - $info{"date"} ) / 86400 ) < $params{"days"};    #24*60*60
        $new =
          $updated && ( ( $info{"version"} + 0 ) <= ( $params{"version"} + 0 ) );

        $r = "";
        if ($updated) {
            $r = " %U%";
        }
        if ($new) {
            $r = " %N%";
        }

        # revert to old style wikiword formatting
        $wikiword = $oldwikiword;

        return $r;

    }
    else {
        return "";
    }
}

# =========================
sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

# Match WikiWordAsWebName.WikiWord, WikiWords, [[WikiWord][link text]], [[WebName.WikiWord][link text]], [[link text]], [[linktext]] or WIK IWO RDS (all followed by %ISNEW..% syntax)
    $_[0] =~
s/($wnre\.$wwre|$wwre|\[\[$wwre\]\[.*?\]\]|\[\[$wnre}\.$wwre\]\[.*?\]\]|\[\[.*?\]\]|$abbre) %ISNEW({.*?})?%/"$1".update_info($web, $1, $2)/geo;

}

1;
