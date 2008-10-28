use lib ('.');
use lib ('../../../..');
use integer;

use Assert;
use TWiki::Plugins::TocPlugin::TOC;
use TWiki::Plugins::TocPlugin::TopLevelSection;
use FakeWikiIF;

{ package TOCTests;
  use HTML;

  my $topic1 = "TopLevel";
  my $topic2 = "ReferToMe";
  my $wif = FakeWikiIF->getInterface("Test", $topic1);

  FakeWikiIF::writeTopic("WebOrder","\t* $topic1\n\t* $topic2");
  FakeWikiIF::writeTopic($topic1, "Blah");
  FakeWikiIF::writeTopic($topic2, "%SECTION1{name=refme}% Refer to me");

  my $text = "%SECTION0% Section zero
%SECTION1{name=oneone}% Section one.one
%ANCHOR{type=Figure,name=ref}% Figure anchor
%SECTION1% Section one.two
%REF{type=Figure,name=ref}% A ref to ref
";

  $mess = TOC::processTopic($wif, "Test", $topic1, $text);
  my $secs = "<H1>${TS}Section_1.${TE}1.  Section zero$AE</H1>
<H2>${TS}Section_1.1.${TE}1.1. Section one.one$AE${TS}Section_oneone$TE $AE
</H2>
${TS}Figure_ref${TE}1.1.A Figure anchor</A>
<H2>${TS}Section_1.2.${TE}1.2. Section one.two</A></H2>
${JS}$topic1#Figure_ref${JE}1.1.A Figure anchor</A> A ref to ref";
  Assert::sEquals(__LINE__, $mess, $secs);

  # check global tags
  $mess = TOC::processTopic($wif, "Test", $topic1,
"$text %CONTENTS% %TOCCHECK% %REFTABLE{type=Figure}%");
  Assert::sEquals(__LINE__, $mess,
"$secs
 $DIV
$UL$LI${JS}$topic1${TE}1.  Section zero</A>$UL
$LI${JS}$topic1#Section_1.1.${TE}1.1. Section one.one$AE$IL
$LI${JS}$topic1#Section_1.2.${TE}1.2. Section one.two$AE$IL
$LU$IL
$LI${JS}$topic2${TE}2. <nop>ReferToMe$AE$UL
$LI${JS}$topic2#Section_2.1.${TE}2.1. Refer to me$AE$IL
$LU$IL
$LU$VID$REFT
$TR${TH}Figure$HT$RT
$TR$TD${JS}$topic1#Figure_ref${JE}1.1.A Figure anchor$AE$DT$RT
$TFER");

  # Check topic->topic cross reference
  $mess = TOC::processTopic($wif, "Test", $topic1,
"%REF{topic=$topic2,type=Section,name=refme}%");
  Assert::sEquals(__LINE__, $mess,
"${JS}$topic2#Section_2.1.${JE}2.1. Refer to me$AE");

# the wif should cache the web
# the wif should be renewed if the web changes
};

1;
