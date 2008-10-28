#!/usr/bin/perl

##############################################################################
# MTVWebdesign MailPage                        Version 2.0   
# mailpage.cgi: The main script                            
# Copyright 1999-2000 Maarten Veerman mtveerman@mindless.com                   
# MTVWebdesign:    http://mtvwebdesign.hypermart.net/ (http://mtvwebdesign.hypermart.net/scripts/)      
##############################################################################
# COPYRIGHT NOTICE                                                           
# Copyright 1999-2000 Maarten Veerman  All Rights Reserved.                
#                                                                            
# MailPage may be used and modified so long as this 
# copyright notice and the comments above remain intact.  By using this      
# code you agree to indemnify Maarten Veerman from any liability that    
# might arise from its use.                                                  
#                                                                            
# Selling the code for this program without prior written consent is         
# expressly forbidden.  In other words, please ask first before you try and  
# make money off of my program in any way.                                              
#                                                                            
# Obtain permission before redistributing this software over the Internet or 
# in any other medium. In all cases copyright and header must remain intact 
# 
# Please send bug-reports to cgi-bugs@mtvwebdesign.hypermart.net
##############################################################################
#
# Script tested locally:
# Pentium 400Mhz, 128MB RAM, Windows 98, Apache 1.3.4 (win32), Perl, MS Internet Explorer 5.0, Netscape 4.05.
#
##############################################################################
# Please do not remove the following lines:
$scriptname = "MailPage";
$version = "2.0";
##############################################################################

use LWP::UserAgent;
$ua = new LWP::UserAgent;
$ua->agent("$ENV{'HTTP_USER_AGENT'}");
use CGI::Carp qw(fatalsToBrowser); # Provides you with fatal error message if they occur.
use CGI qw/:standard/;
require '/home/httpd/twiki/bin/mailpage/mailpage.conf';
require $mtvwebdesignlib;

main: {
&getinput;
&GetCookies;

if (lc $FORM{'action'} eq "send") { &getbase($FORM{'url'}); &send; }
elsif (lc $FORM{'action'} eq "privacy") {&privacy;}
else { &moreinfo }

exit;
}


sub moreinfo {
$FORM{'url'} = $ENV{'HTTP_REFERER'} unless $FORM{'url'};
if ($FORM{'url'} !~ m/^http/ ) { $FORM{'url'} = $ENV{'HTTP_REFERER'}; }

print "Content-type: text/html\n\n";
&pageheader("SUGGEST THIS PAGE TO A FRIEND...");
foreach $line (@temptoken) {
	if ($line =~ m/$token/i) {
print qq~
<form action="$ENV{'SCRIPT_NAME'}" method="post">
<input type="hidden" name="action" value="send">
<input type="hidden" name="url" value="$FORM{'url'}">
 <h1 align="center">
  SUGGEST THIS PAGE TO A FRIEND...</h1>
      <CENTER>
<P>                                                               
<TABLE WIDTH=550>
 <TR>
 <TD>
  <B>
 <FONT FACE="ARIAL" SIZE=4 COLOR="#009999">
  <P align="center">
  <A HREF="$ENV{'HTTP_REFERER'}">$ENV{'HTTP_REFERER'}</A>
  </FONT>
  </B>
  <BLOCKQUOTE>
 <FONT FACE="ARIAL" SIZE=2 COLOR="#000000">
  If you have a friend that you would like to recommend this page to,
  or if you just want to send yourself a reminder, here is the easy
  way to do it!
  <P>
  Simply fill in the e-mail address of the person(s) you wish to tell
  about $sitename, your name and e-mail address (so they do
  not think it is spam or reply to us with gracious thanks),
  and click the <B>SEND</B> button.
  If you want to, you can also enter a message that will be included
  in the e-mail.
  <P>
  After sending the e-mail, you will be transported back to the
  page you recommended!
 </FONT>
 <BR><font size="1"><a href="$ENV{'SCRIPT_NAME'}?action=privacy" target="_new">Click here</a> to read our privacy policy</font>
   <TABLE BORDER=0 CELLPADDING=1 CELLSPACING=0 >
    <TR>
    <TD>&nbsp;</TD>
    <TD ALIGN=CENTER><B>Name</B></TD>
    <TD ALIGN=CENTER><B>E-Mail Address</B><TD>
    </TR>

    <TR>
    <TD><B>You</B></TD>
    <TD><input type="text" name="sendername" value="$Cookies{'name'}"></TD>
    <TD><input type="text" name="senderemail" value="$Cookies{'email'}"></TD>
    </TR>
    <TR>
    <TD><B>Friend $i</B></TD>
    <TD><input type="text" name="recipient"></TD>
    <TD><input type="text" name="recipientemail"></TD>
    </TR>
   <TR>
   <TD colspan="3">&nbsp;<B>Your Message</B><BR>
 <textarea name="message" wrap=virtual rows=5 cols=59></textarea>
    <BR>
    How would you like to send this page?
    <BR>
    <select name="how"><option value="body">In the body of the email<option value="attachment">As attachment<option value="url">As an URL</select>
    <BR>
    <INPUT TYPE="submit" VALUE="SEND">
   </TD>
    </TR>
  </TABLE>
  </BLOCKQUOTE>
 <I>
 </i>
  </TD>
  </TR>
  </TABLE>
</center>
</form>
~;
	}
print "$line";
}
&powered_by("nologout");
exit;
}

sub send {

&check_email($FORM{'senderemail'});
&check_email($FORM{'recipientemail'});

&send_email;

&SetCookies("name",$FORM{'sendername'},"email",$FORM{'senderemail'});
print "Content-type: text/html\n\n";
&pageheader("Send!");
foreach $line (@temptoken) {
	if ($line =~ m/$token/i) {
print qq~
<h2>Send!</h2>
The email has been sent to $FORM{'recipient'}. Please click the back button below to return to the page you were before.<p>
<center><FORM><INPUT type="button" value="Back" onClick="window.location='$FORM{'url'}'"></FORM></center>
~;
	}
print "$line";
}
&powered_by("nologout");
$JUMP_TO = $ENV{'HTTP_REFERER'};
exit;
}

sub send_email {

if ($FORM{'how'} eq "body") { &send_body; }
elsif ($FORM{'how'} eq "attachment") { &send_attached; }
else { &send_plain; }

}

sub send_plain {
open MAIL, "$mailprog" || die "Cannot open $mailprog so I cannot sent email";
print MAIL "To: $FORM{'recipientemail'} ($FORM{'recipient'})\n";
print MAIL "From: $FORM{'senderemail'} ($FORM{'sendername'})\n";
print MAIL "Subject: $FORM{'sendername'} wants you to have a look at a page!!\n\n";
print MAIL qq~
Dear $FORM{'recipient'},

$FORM{'sendername'} wants you to look at the following page:
$FORM{'url'}
~;

if ($FORM{'message'}) {
print MAIL qq~
$FORM{'sendername'} also wanted to tell you this:
$FORM{'message'}
~;
}

print MAIL qq~

This email was sent by $servicename, located at $servicelocation
Script by MTVWebdesign, http://mtvwebdesign.hypermart.net
~;

close MAIL;
}

# The following sub was modified by Lynnwood Brown on 1/31/05 to for use with TWiki. It sends the "print" view.
sub send_body {
$req = new HTTP::Request 'GET' => $FORM{'url'}."?template=viewprint";
$res = $ua->request($req);

if ($res->is_success) {
#print "Content-type: image/gif\n\n";
#print $res->content;


$header = "Dear $FORM{'recipient'},<br><br>$FORM{'sendername'} has sent you this email, including a webpage which you can also visit by <a href=\"$FORM{'url'}\">clicking here</a>!<br><br>";
if ($FORM{'message'}) { $header .= "$FORM{'sendername'} also wanted to tell you this:<br>$FORM{'message'}"; }

$header .= "<p>This email was sent from <a href=\"$servicelocation\">$servicename</a><br>";

$header .= "<hr noshade>\n";

open MAIL, "$mailprog" || die "Cannot open $mailprog so I cannot sent email";
print MAIL "To: $FORM{'recipientemail'} ($FORM{'recipient'})\n";
print MAIL "From: $FORM{'senderemail'} ($FORM{'sendername'})\n";
print MAIL "Subject: $FORM{'sendername'} has sent you a page!!\n";
print MAIL "Content-type: text/html\n\n";

foreach $line ($res->content) {
if ($line =~ /\<body/ig) { $line =~ s/<body(.*?)\>/\<body $1\>$header/ig;}
if ($line =~ /\<head/ig) { $line =~ s/<head>/<head><base href=\"$base\">/ig;}
print MAIL $line; 
}

close MAIL;

}
else {
&send_plain;
}

}

sub send_attached {
$req = new HTTP::Request 'GET' => $FORM{'url'};
$res = $ua->request($req);

if ($res->is_success) {
#print "Content-type: image/gif\n\n";
#print $res->content;

open MAIL , "$mailprog" || die "Cannot open $mailprog";
print MAIL "MIME-Version: 1.0\n";
print MAIL "Content-type: multipart/mixed; boundary=\"----=_MAARTEN.ATT\"\n";
print MAIL "To: $FORM{'recipientemail'} ($FORM{'recipient'})\n";
print MAIL "From: $FORM{'senderemail'} ($FORM{'sendername'})\n";
print MAIL "Subject: $FORM{'sendername'} has sent you a page!!\n\n";
print MAIL qq~
------=_MAARTEN.ATT
Content-Transfer-Encoding: quoted-printable
Content-Type: text/plain; charset=US-ASCII

Dear $FORM{'recipient'},

$FORM{'sendername'} wants you to look at the attached page:
$FORM{'url'}
~;

if ($FORM{'message'}) {
print MAIL qq~
$FORM{'sendername'} also wanted to tell you this:
$FORM{'message'}
~;
}

print MAIL qq~

This email was send from $servicename, located at $servicelocation
~;


print MAIL "------=_MAARTEN.ATT\n";
print MAIL "Content-Type: text/html\;name=\"test.html\"\n";
print MAIL "Content-Transfer-Encoding: 8bit\n";
print MAIL "Content-Disposition: attachment\;filename=\"test.html\"\n\n";

foreach $line ($res->content) {
if ($line =~ /\<head/ig) { $line =~ s/<head>/<head><base href=\"$base\">/ig;}
print MAIL $line;
}
print MAIL "\n";


print MAIL "\n------=_MAARTEN.ATT--\n";


close MAIL;

}
else {
&send_plain;
}
}

sub privacy {
print "Content-type: text/html\n\n";
&pageheader("Privacy Policy");
foreach $line (@temptoken) {
	if ($line =~ m/$token/i) {
print qq~
<h2>Privacy Policy</h2>
~;

open FILE, $privacy_file || die "Cannot open $privacy_file";
flock(FILE, 2) if $use_flock;
@lines = <FILE>;
flock(FILE, 8) if $use_flock;
close FILE;

print @lines;

	}
print "$line";
}
&powered_by("nologout");
}

sub getbase {
local($baseurl) = @_;

if ($baseurl =~ /\.html?$/i) {
@items = split(/\//,$baseurl);

$n = scalar @items;
$n--;

for($i=0;$i<$n;$i++) {
$base .= @items[$i] . "/";
}


}
else { $base = $baseurl; }
}

sub errors {
local($errors) = @_;

&expires_header("now");
print "Content-type: text/html\n\n";
&pageheader('An error occured');
foreach $line (@temptoken) {
	if ($line =~ m/$token/i) {
		if ($errors eq 'with the email address you gave') {
			print qq~
			<h2>Invalid email address</h2>
			The following email address is invalid: $invalidmail<br>
			Please press the back button and try again.
			~;
		}


# If the error type was not found:
		else {
		print qq~
		Error Undefined! Please contact <a href="mailto:$webmasteremail?subject=Error_Undefined">$webmasteremail</a> and be detailed in what you did what caused the error.
		~;
		}

# Back button:
print qq~
<center><FORM><INPUT type="button" value="Back" onClick="history.go(-1)"></FORM></center>
~;
	}
	print "$line";
}
&powered_by("nologout");
$JUMP_TO = $ENV{'HTTP_REFERER'};
exit; # Exit the script when an error occured.
}

