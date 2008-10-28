# Detail for SignaturePlugin
#

package TWiki::Plugins::SignaturePlugin::Signature;

# Always use strict to enforce variable scoping
use strict;

sub handleSignature {
  my ( $cnt, $attr ) = @_;
  my $session = $TWiki::Plugins::SESSION;

  $attr = new TWiki::Attrs($attr);
  my $lbl = TWiki::Func::getPreferencesValue( "\U$TWiki::Plugins::SignaturePlugin::pluginName\E_SIGNATURELABEL" ) || 'Sign';

  my $name = '';
  $name = '_('.$attr->{name}.')_ &nbsp;' if $attr->{name};

  return "<noautolink> $name </noautolink><form action=\"" . &TWiki::Func::getScriptUrl($session->{webName}, $session->{topicName}, 'digisign') . "\" /><input type=\"hidden\" name=\"nr\" value=\"$cnt\" /><input type=\"submit\" value=\"$lbl\" /></form>";

}

sub sign {
  my $session = shift;
  $TWiki::Plugins::SESSION = $session;
  my $query = $session->{cgiQuery};
  return unless ( $query );

  my $cnt = $query->param( 'nr' );

  my $webName = $session->{webName};
  my $topic = $session->{topicName};
  my $user = $session->{user};
  return unless ( &doEnableEdit ($webName, $topic, $user, $query, 'editTableRow') );

  my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
  $text =~ s/%SIGNATURE(?:{(.*)})?%/&replaceSignature($cnt--, $user, $1)/geo;

  my $error = &TWiki::Func::saveTopicText( $webName, $topic, $text, 1 );
  TWiki::Func::setTopicEditLock( $webName, $topic, 0 );  # unlock Topic
  if( $error ) {
    TWiki::Func::redirectCgiQuery( $query, $error );
    return 0;
  } else {
    # and finally display topic
    TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $webName, $topic ) );
  }
  
}

sub replaceSignature {
  my ( $dont, $user, $attr ) = @_;

  return ( ($attr)?"%SIGNATURE{$attr}%":'%SIGNATURE%' ) if $dont;

  $attr = new TWiki::Attrs($attr);

  unless ( ! $attr->{name} || $user->isInList( $attr->{name} )) {
    my $session = $TWiki::Plugins::SESSION;
    TWiki::Func::setTopicEditLock( $session->{webName}, $session->{topicName}, 0 );  # unlock Topic
    throw TWiki::OopsException( 'generic',
				web => $session->{webName},
				topic => $session->{topicName},
				params => [ 'Attention', $user->wikiName.' is not permitted to sign here.',  'Please go back in your browser and sign at the correct spot.', ' ' ] );
    exit;
  }

  my $fmt = $attr->{format} || TWiki::Func::getPreferencesValue( "\U$TWiki::Plugins::SignaturePlugin::pluginName\E_SIGNATUREFORMAT" ) || '$wikiusername - $date';

  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my ($d, $m, $y) = (localtime)[3, 4, 5];
  $y += 1900;
  my $ourDate = sprintf('%02d %s %d', $d, $months[$m], $y);

  $fmt =~ s/\$quot/\"/go;
  $fmt =~ s/\$wikiusername/$user->webDotWikiName()/geo;
  $fmt =~ s/\$wikiname/$user->wikiName()/geo;
  $fmt =~ s/\$username/$user->login()/geo;
  $fmt =~ s/\$date/$ourDate/geo;

  return $fmt;

}

sub doEnableEdit
{
    my ( $theWeb, $theTopic, $user, $query ) = @_;

    if( ! &TWiki::Func::checkAccessPermission( "change", $user, "", $theTopic, $theWeb ) ) {
        # user does not have permission to change the topic
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $_[2],
                                    topic => $_[1],
				    params => [ 'Edit topic', 'You are not permitted to edit this topic' ] );
	return 0;
    }

    ## SMELL: Update for TWiki 4.1 =checkTopicEditLock=
    my( $oopsUrl, $lockUser ) = &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'edit' );
    if( $lockUser && ! ( $lockUser eq $user->login ) ) {
      # warn user that other person is editing this topic
      &TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
      return 0;
    }
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;

}

1;
