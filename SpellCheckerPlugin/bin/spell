#!/usr/bin/perl -w
#$|=1;
# WBOSS, Web Based Open Source Spellchcker Version 2.1
# Copyright 2001, Joshua Cantara <jcantara@grappone.com>
# WordFrame code by Chung-Ki Tung | Ispell code by John D. Porter
# This program is licensed under the GPL.

#####################################
# LOAD MODULES!
#####################################
use CGI;
use IPC::Open3;

##MWB Debug
use lib ( '.' );
use lib ( '../lib' );
use TWiki;

#####################################
# WHICH SPELL CHECKER TO USE?
# CHANGE THIS VARIABLE IF NEEDED!!!
#####################################
#$path = '/usr/bin/aspell';
$path = '/usr/bin/ispell';

######################################
# SET GLOBAL VARIABLES
######################################
@words=();		# global
$wordframe="";	# global
$wordcount=0;	# global
$worderror=0;	# global
$wordignore="";	# global
$pageheaders = qq|
<style>
body	{
	font-family:tahoma,sans-serif;
	font-size:11px;
	color: #000000;
	margin-top:10px;
	margin-left:10px;
	margin-right:0px;
	margin-bottom:2px;
	background:#F9F9F9;
	text-align:center;
}

input	{
	font-family:tahoma,sans-serif;
	font-size:11px;
	background-color : #FFFFF0;
	border : 1px solid #696969;
	color : #003366;
	font-weight : bold;
}

select	{
	font-family:tahoma,sans-serif;
	font-size:11px;
	background : #FFFFF0;
	color : #003366;
	font-weight : bold;
}

textarea	{
	font-family:tahoma,sans-serif; 
	font-size:11px;
	background-color : #FFFFF0;
	border : 1px solid #696969;
	color : #003366;
	font-weight : bold;
}

a {
	color: #003366;
	font-family: tahoma,sans-serif;
	font-size: 14px;
	font-weight : bold;
	text-decoration : none;
}

td.bold {
	font-family: tahoma,sans-serif;
	font-size: 14px;
	font-weight : bold;
}

td.header {
	font-family: tahoma,sans-serif;
	font-size: 20px;
	font-weight : bold;
}

</style>
|;

#####################################
# input split/join 
#####################################
sub _word2label {
my $word=$_[0];
my $label='%%WORD'.$wordcount.'%%';
if ($wordignore=~/$word/i || $word =~/^WORD/) 
	{
	return($word);
	}
$words[$wordcount]=$word;
$wordcount++;
return($label);
}

##################################################
# fill $wordframe and @words by spliting the input
##################################################
sub text2words {
my $text=$_[0];

# ignore valid contractions
$wordignore  = "they'll we'll you'll she'll he'll i'll ";
$wordignore .= "hasn't wouldn't shouldn't didn't aren't couldn't doesn't hadn't wasn't weren't isn't ";
$wordignore .= "we've you've they've ";

# ignore the following always
$wordignore .= "http ftp nntp smtp nfs html xml mailto bsd linux gnu gpl openwebmail ";

# open custom ignore
if (-e 'custom.dic')
	{
	local $/ = undef;
	open(DICTIONARY, '<custom.dic');
	my $file = <DICTIONARY>;
	$file =~ s/\n/ /;
	$wordignore .= $file;
	}

# put url to ignore
foreach ($text=~m![A-Za-z]+tp://[A-Za-z\d\.]+!ig) 
	{
	$wordignore.=" $_";
	}
# put email to ignore
foreach ($text=~m![A-Za-z\d]+\@[A-Za-z\d]+!ig) 
	{
	$wordignore.=" $_";
	}
# put FQDN to ignore
foreach ($text=~m![A-Za-z\d\.]+\.(com|org|edu|net|gov)[A-Za-z\d\.]*!ig)
	{
	$wordignore.=" $_";
	}

@words=();
$wordcount=0;
$wordframe=$text;
$wordframe=~s/([A-Za-z][A-Za-z\-]*[A-Za-z])|(~~[A-Za-z][A-Za-z\-]*[A-Za-z])/_word2label($1)/ge;
return $wordcount;
}   

###########################################
# fill $wordframe and @words by CGI $query
###########################################
sub query2words {
my $q=$_[0];
my $i;
@words=();
$wordcount=$q->param('wordcount');
$wordframe=CGI::unescape($q->param('wordframe'));
for ($i=0; $i<$wordcount; $i++)
	{
	$words[$i]=$q->param($i) if (defined ($q->param($i)))
	}
}

#########################################
# build output from $wordframe and @words
#########################################
sub words2text {
my $text=$wordframe;
$text=~s/%%WORD(\d+)%%/$words[$1]/ge;
$text=~s/~~([A-Za-z]*)/$1/ge;		# covert manualfix to origword
return($text);
}

##############################################################
# generate html from $wordframe and @words and do spellcheck()
##############################################################
sub words2html {
my $html=$wordframe;
my $i;

# conversion to make html display happy
$html=~s/&/&amp;/g;
$html=~s/</&lt;/g;
$html=~s/>/&gt;/g;
$html=~s/\n/<BR>/g;
$html=~s/"/&quot;/g;
$html=~s/ ( +)/&nbsp;$1/g;           #"

for ($i=0; $i<$wordcount; $i++)
	{
	my $wordhtml="";
	if ( $words[$i]=~/^~~/ )	# check if manualfix
		{	
		my $origword=substr($words[$i],2);
		my $len=length($origword);
		$wordhtml=qq|<input type="text" size="$len" name="$i" value="$origword">\n|;
		$worderror++;
		}
	else	{				# normal word
		&TWiki::Func::writeDebug("checking this word: $words[$i]");
                my ($r) = spellcheck($words[$i]);
		&TWiki::Func::writeDebug("my r = $r");
                &TWiki::Func::writeDebug("my r type = $r->{'type'}");
                if ($r->{'type'} eq 'none' || $r->{'type'} eq 'guess')
			{
 			my $len=length($words[$i]);
			$wordhtml=qq|<input type="text" size="$len" name="$i" value="$words[$i]">\n|;
			$worderror++;
			}
		elsif ($r->{'type'} eq 'miss')
			{
			my $sugg; 
			$wordhtml=qq|<select size="1" name="$i">\n|.
			qq|<option>$words[$i]</option>\n|.
			qq|<option value="~~$words[$i]">--Manually Fix--</option>\n|;
			foreach $sugg (@{$r->{'misses'}})
				{
				$wordhtml.=qq|<option>$sugg</option>\n|;
				}
			$wordhtml.=qq|</select>\n|;
			$worderror++;
			} 
		else	{		# type= ok, compound, root
           		$wordhtml=qq|$words[$i]|;
           		$wordframe=~s/%%WORD$i%%/$words[$i]/; # remove the word symbo from wordframe
			}
		}
	$html=~s/%%WORD$i%%/$wordhtml/;
	}
return($html);
}

#####################################
# CHECKS THE TEXT FOR ERRORS 
# AND ASKS FOR VERIFICATION
#####################################
sub checkit {
my ($formname,$fieldname) = @_;

# escapedwordframe must be done after words2html()
# since $wordframe may changed in words2html()
my $wordshtml = words2html();
my $escapedwordframe = CGI::escape($wordframe);

print qq|
<html>
<head>
$pageheaders
<title>
Text Checked
</title>
<body onLoad="self.focus();">
<center>
<form method="POST" action="/twiki/bin/spell.pl">
<table border="0">
<tr>
<td align="center" class="header">
Verify Spell Check
</td>
</tr>
<tr>
<td valign="top">
&nbsp;&nbsp;&nbsp;&nbsp;
Drop the boxes below down to choose a suggested replacement, 
keep your original, or choose "--Manually Fix--" and then "Check Again" 
if none of the suggestions fit what you intended. 
A text box appears if no suggestions were found. Retype the word, and try again.
</td>
</tr>
<tr>
<td valign="top">
<center>
<table border="0" cellpadding="2" cellspacing="1">
<tr>
<td valign="top" class="bold">
$wordshtml
</td>
</tr>
</table>
<input type="hidden" name="wordframe" value="$escapedwordframe">
<input type="hidden" name="wordcount" value="$wordcount">
<br>
<input type="submit" name="Check Again" value="Check Again">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="submit" name="Finish Checking" value="Finish Checking">
<br>
<br>
Go <a href="#" onclick="window.history.back()">back</a> to the previous page.
</td>
</tr>
</table>
<input type="hidden" name="form" value="$formname">
<input type="hidden" name="field" value="$fieldname">
</form>
</body>
</html>
|;
}

#####################################
# FINAL
#####################################
sub final {
my ($formname, $fieldname) = @_;
my $escapedfinalstring=words2text();

# since jscript has problem in unescape doublebyte char string, 
# we only escape " to !QUOT! and unescape in jscript by RegExp
# $escapedfinalstring=CGI::escape(words2text());
$escapedfinalstring=~s/"/!QUOT!/g;  #"

print qq|
<html>
<head>
$pageheaders
<title>
Done Checking!
</title>
</head>
<body>
<center>
<form name="done">
<table border="0" cellpadding="2" cellspacing="1">
<tr>
<td align="center" class="header">
Insert Into Your Original Page
</td>
</tr>
<tr>
<td valign="top" align="center">
<textarea rows="12" cols="50" name="checked">$escapedfinalstring</textarea>
<br>
<br>
<input type="button" name="Insert" value="Insert in Document" onclick="window.opener.document.$formname.$fieldname.value=document.done.checked.value;window.close();">
<tr>
<td align="center">
Click <a href="/twiki/bin/spell.pl">here</a> to check more text.
<br>
Click <a href="#" onclick="window.close();">here</a> to close this window.
</td>
</tr>
</table>
<input type="hidden" name="form" value="$formname">
<input type="hidden" name="field" value="$fieldname">
</form>
<script language="JavaScript">
   <!--
   unescape_string();

   function unescape_string() 
   {
   var quot = new RegExp("!QUOT!","g");
   // unescape !QUOT! to "
   document.done.checked.value=(document.done.checked.value.replace(quot,'"'));
   }
   //-->
</script>
</body>
</html>
|;
}

#####################################
# ASKS FOR TEXT TO CHECK
#####################################
sub asktext {
print qq|
<html>
<head>
$pageheaders
<title>
Spell Checker
</title>
</head>
<body>
<center>
<table border="0" cellpadding="2" cellspacing="1">
<tr>
<td align="center" class="header">
Please Copy and Paste Text Below
<td>
</tr>
<tr>
<td align="center">
<form action="/twiki/bin/spell.pl" method="POST">
<textarea rows="8" cols="50" name="checkme"></textarea>
<br>
<input type="hidden" name="spell" value="check">
<input type="submit" name="Submit" value="Submit">
<br>
<br>
<b>Click <a href="#" onclick="window.close();">here</a> to close this window.</b>
</td>
</tr>
</table>
</form>
</body></html>
|;
}

#####################################
# DISPLAYS ERROR MESSAGE
#####################################
sub error {
print qq|
<html>
<head>
$pageheaders
<title>
Spell Checker Error
</title>
</head>
<body>
<center>
<h2>An error has occured.
<br>
You are not authorized to use this spellcheck script.</h2>
</center>
</body>
</html>
|;
}

#######################################
# DEBUG SUB ROUTINE
# Useage: &debug();
#######################################
sub debug {
my $q = new CGI;
print '<!--// ';
foreach ($q->param) 
   {
   print "$_";
   print " : ";
   print $q->param("$_");
   print "\n";
   }
print '//-->';
}

#####################################
# MAIN LOOP!
#####################################
my $query = new CGI;
my $string = $query->param('checkme');
my $form = $query->param('form');
my $field = $query->param('field');

untie *STDIN;

print "Content-type: text/html\n\n";
if ($query->param('spell') eq 'check')
	{
	if ($ENV{HTTP_REFERER} !~ $ENV{HTTP_HOST})
		{
		&error;
		exit;
		}
	$pid = open3(\*WRITER,\*READER,\*ERROR,"$path -a -S") or die "Can't open aspell!";
	&TWiki::Func::writeDebug("my open3 PID = $pid");
        text2words($string);
	checkit($form, $field);
	close READER;
	close WRITER;
	wait;
	} 
elsif ($query->param('Finish Checking') eq 'Finish Checking')
	{
	query2words($query);
	final($form, $field);
	}
elsif ($query->param('Check Again') eq 'Check Again')
	{
	$pid = open3(\*WRITER,\*READER,\*ERROR,"$path -a -S") or die "Can't open aspell!";
	query2words($query);
	checkit($form,$field);
	close READER;
	close WRITER;
	wait;
	} 
else	{
	&asktext;
	}

exit;

################################################
# SPELLCHECK SUBROUTINE!
################################################
sub spellcheck {
my $pid = undef;
my $word = shift(@_);
my @commentary;
my @results;
my %types = (
	# correct words:
	'*' => 'ok',
	'-' => 'compound',
	'+' => 'root',
	# misspelled words:
	'#' => 'none',
	'&' => 'miss',
	'?' => 'guess',
	);
my %modisp = (
	'root' => sub {
		my $h = shift;
		$h->{'root'} = shift;
		},
	'none' => sub {
		my $h = shift;
		$h->{'original'} = shift;
		$h->{'offset'} = shift;
		},
	'miss' => sub { # also used for 'guess'
		my $h = shift;
		$h->{'original'} = shift;
		$h->{'count'} = shift; # count will always be 0, when $c eq '?'.
		$h->{'offset'} = shift;
		my @misses  = splice @_, 0, $h->{'count'};
		my @guesses = @_;
		$h->{'misses'}  = \@misses;
		$h->{'guesses'} = \@guesses;
		},
	);
$modisp{'guess'} = $modisp{'miss'}; # same handler.
chomp $word;
$word =~ s/\r//g;
$word =~ /\n/ and warn "newlines not allowed";

print WRITER "!\n";
print WRITER "^$word\n";

while (<READER>)
	{
	chomp;
	last unless $_ gt '';
	push (@commentary, $_) if substr($_,0,1) =~ /([*|-|+|#|&|?| ||])/;
	}

for my $i (0 .. $#commentary)
	{
	my %h = ('commentary' => $commentary[$i]);

	my @tail; # will get stuff after a colon, if any.
	if ($h{'commentary'} =~ s/:\s+(.*)//)
		{
		my $tail = $1;
		@tail = split /, /, $tail;
		}

	my($c,@args) = split ' ', $h{'commentary'};
	my $type = $types{$c} || 'unknown';
	$modisp{$type} and $modisp{$type}->( \%h, @args, @tail );
	$h{'type'} = $type;
	$h{'term'} = $h{'original'};
	push @results, \%h;
	}

return $results[0];
}
