use lib ('.');
use lib ('../../../..');
use integer;

use Assert;
use TWiki::Plugins::TocPlugin::Attrs;
use TWiki::Plugins::TocPlugin::TopLevelSection;
use FakeWikiIF;

{ package TopLevelSectionTests;
  use HTML;

  my $l1text = "TopLevel";
  my $l1texp ="<nop>TopLevel";
  my $l2text = "SecondLevel";
  my $l2texp ="<nop>SecondLevel";
  my $l3text = "ThirdLevel";
  my $l3texp ="<nop>ThirdLevel";

  my $l1btext = "AnotherTopLevel";
  my $l1btexp = "<nop>$l1btext";
  my $l2btext = "AnotherSecondLevel";
  my $l2btexp = "<nop>$l2btext";

  my $wif = FakeWikiIF->getInterface("Test", $l1btext);

  my ($root, $mess) = TopLevelSection::createTOC("Test", $wif);

  Assert::sEquals(__LINE__, $mess, "${ERF}No WebOrder in this web$FRE");
  FakeWikiIF::writeTopic("WebOrder",
"\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext
\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext
");
  ($root, $mess) = TopLevelSection::createTOC("Test", $wif);
  Assert::sEquals(__LINE__, $mess,
"${ERF}Topic $l1text used more than once in WebOrder<br>$FRE
${ERF}Topic $l2text used more than once in WebOrder<br>$FRE
${ERF}Topic $l3text used more than once in WebOrder<br>$FRE
${ERF}Topic $l2btext used more than once in WebOrder<br>$FRE
${ERF}Topic $l1btext used more than once in WebOrder<br>$FRE");

  FakeWikiIF::writeTopic("WebOrder",
"\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext\n");
  my $l2tagtext = "Tagged LevelTwo Section";
  my $l2tagtexp = "Tagged <nop>LevelTwo Section";
  FakeWikiIF::writeTopic($l1text, "%SECTION1% $l2tagtext");
  my $l3tagtext = "Tagged LevelThree Section";
  my $l3tagtexp = "Tagged <nop>LevelThree Section";
  FakeWikiIF::writeTopic($l2text, "%SECTION1% $l3tagtext");
  my $l4tagtext = "Tagged LevelFourSection";
  my $l4tagtexp = "Tagged <nop>LevelFourSection";
  FakeWikiIF::writeTopic($l3text, "%SECTION1% $l4tagtext");
  FakeWikiIF::writeTopic($l1btext, "%SECTION0% $l1btexp");
  FakeWikiIF::writeTopic($l2btext, "%SECTION0% $l2btexp");

  ($root, $mess) = TopLevelSection::createTOC("Test", $wif);
  die $mess unless $root;
  Assert::sEquals(__LINE__, $root->processTOCTag(TocPlugin::Attrs->new("")),
"$DIV
$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI${JS}$l3text#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI${JS}$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LI$JS$l1btext${JE}2. $l1btexp$AE$IL
$LU$VID");
  Assert::sEquals(__LINE__, $root->processTOCTag(TocPlugin::Attrs->new("topic=$l1text")),
"$DIV
$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI$JS${l3text}#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI$JS$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LU$VID");

  my $tt = $root->_findTopic($l1btext);
  Assert::assert(__LINE__, $tt->wikiName() eq $l1btext);
  Assert::assert(__LINE__, $tt->{IS_LOADED});
  my $ct = $root->currentTopic();
  Assert::sEquals(__LINE__, $ct->wikiName(), $l1btext);
  Assert::assert(__LINE__, $ct->{IS_LOADED});

  $root->loadTopics($root);
  Assert::sEquals(__LINE__, $root->processTOCTag(TocPlugin::Attrs->new("")),
"$DIV$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI$JS$l3text#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI$JS$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LI$JS$l1btext${JE}2. $l1btexp$AE$IL
$LU$VID");

  Assert::sEquals(__LINE__, $root->processTOCCHECKTag(), "");
  FakeWikiIF::writeTopic("Missing", "");
  Assert::sEquals(__LINE__, $root->processTOCCHECKTag(), 
"${ERF}The following topics were not found in the WebOrder:
<OL>${LI}Missing$IL</OL>$FRE");

  Assert::sEquals(__LINE__, $root->processREFTABLETag(TocPlugin::Attrs->new("")),
"${ERF}Bad type in REFTABLE$FRE");
  Assert::sEquals(__LINE__, $root->processREFTABLETag(TocPlugin::Attrs->new("type=fred")),
"$REFT$TR${TH}fred$HT$RT$TFER");

}
1;
