use strict;

package MailInContribSuite;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );
use File::Path;
use Error qw( :try );
use TWiki::Contrib::MailInContrib;

my $box;

my @mails; # sent mails

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{system_web} = 'TemporaryMailInContribSuiteSystemWeb';
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{system_web},
        $TWiki::cfg{SystemWebName} );
    $this->{twiki}->{store}->saveTopic(
        $TWiki::cfg{AdminUserWikiName}, $this->{system_web},
        'WebPreferences', "");

    $TWiki::cfg{SystemWebName} = $this->{system_web};

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();

    my $workdir = TWiki::Func::getWorkArea('MailInContrib');
    open(F, ">$workdir/timestamp") || die $!;
    print F "0\n";
    close(F);
    $this->registerUser('alig',
                        'Ally',
                        'Gator',
                        'ally@masai.mara');
    $this->registerUser('mole',
                        'Mole',
                        'InnaHole',
                        'mole@hill');
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $this->{test_topic}, "");

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $this->{twiki}->net->setMailHandler(\&sentMail);

    $box = {};

    # Make a maildir
    my $tmp = "/tmp/mail$$";
    File::Path::mkpath("$tmp/tmp");
    File::Path::mkpath("$tmp/cur");
    File::Path::mkpath("$tmp/new");
    $box->{folder} = "$tmp/";

    $TWiki::cfg{MailInContrib} = [ $box ];
    @mails = ();
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{twiki}, $this->{system_web} );
    File::Path::rmtree($box->{folder});
    $this->SUPER::tear_down();
}

sub sendTestMail {
    my( $this, $mail ) = @_;
    my $nbr = 1;
    while( -f "$box->{folder}new/mail$nbr" ) {
        $nbr++;
    }
    open(F, ">$box->{folder}new/mail$nbr");
    print F $mail;
    close(F);
}

# callback used by Net.pm
sub sentMail {
    my($net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

sub cron {
    my $this = shift;
    my $min = new TWiki::Contrib::MailInContrib( $this->{twiki}, 0 );
    $min->processInbox( $box );
    $min->wrapUp();
    return $min;
}

sub testBadUserFetch {
    my $this = shift;

    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.$this->{test_topic}\@example.com
Subject: $this->{test_web}.NotHere
From: notauser\@example.com

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'to';
    my $c = $this->cron();
    $this->assert_str_equals('Could not determine submitters WikiName from
From: notauser@example.com
and there is no valid default username', $c->{error});

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},$this->{test_topic});

    $this->assert($t !~ /\S/, $t);
    $this->assert_equals(0, scalar(@mails));
}

# topicPath to and subject
sub testTopicPathTo {
    my $this = shift;


    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.$this->{test_topic}\@example.com
Subject: $this->{test_web}.NotHere
From: mole\@hill

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $mail = <<HERE;
Message-ID: message2
Reply-To: sender2\@example.com
To: "$this->{test_topic} $this->{test_web}" <$this->{test_web}.$this->{test_topic}\@example.com>
Subject: $this->{test_web}.IgnoreThis
From: ally\@masai.mara

Message 2 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'to';
    my $c = $this->cron();
    $this->assert_null($c->{error});

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},$this->{test_topic});

    $this->assert($t =~ s/^ *\* \*$this->{test_web}\.NotHere\*: Message 1 text here\s*-- $this->{users_web}\.MoleInnaHole -\s+\d+\s+\w+\s+\d+\s+-\s+\d+:\d+\n//m, $t);
    $this->assert($t =~ s/^ *\* \*$this->{test_web}\.IgnoreThis\*: Message 2 text here\s*-- $this->{users_web}\.AllyGator -\s+\d+\s+\w+\s+\d+\s+-\s+\d+:\d+\n//m, $t);

    $this->assert_matches(qr/^\s*$/, $t);
    $this->assert_equals(0, scalar(@mails));
}

sub testTopicPathSubject {
    my $this = shift;

    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.NotHere\@example.com
Subject: $this->{test_web}.$this->{test_topic}
From: mole\@hill

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $mail = <<HERE;
Message-ID: message2
Reply-To: sender2\@example.com
To: "$this->{test_topic} IgnoreThis" <$this->{test_web}.IgnoreThis\@example.com>
Subject: $this->{test_web}.$this->{test_topic}: SPAM
From: ally\@masai.mara

Message 2 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'subject';
    my $c = $this->cron();
    $this->assert_null($c->{error});

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},$this->{test_topic});

    $this->assert($t =~ s/^\s*\* \*\*: Message 1 text here\s* -- $this->{users_web}\.MoleInnaHole -\s+\d+\s+\w+\s+\d+\s+-\s+\d+:\d+$//m, $t);
    $this->assert($t =~ s/^ *\* \*SPAM\*: Message 2 text here\s*-- $this->{users_web}\.AllyGator -\s+\d+\s+\w+\s+\d+\s+-\s+\d+:\d+$//m);

    $this->assert_matches(qr/^\s*$/, $t);
    $this->assert_equals(0, scalar(@mails));
}

# defaultWeb set and unset
# existing and nonexisting web in mail
# existing and nonexisting topic in mail
# onNoTopic error and spam
sub testOnNoTopicSpam {
    my $this = shift;

    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.$this->{test_topic}\@example.com
Subject: no valid topic
From: ally\@masai.mara

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'subject';
    $box->{onNoTopic} = 'spam';
    $box->{spambox} = $this->{test_web}.'.DangleBerries';
    $box->{defaultWeb} = $this->{test_web};
    my $c = $this->cron();
    $this->assert_null($c->{error});

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},'DangleBerries');

    $t =~ s/\* \*no valid topic\*: Message 1 text here\s*-- $this->{users_web}.AllyGator -\s+\d+\s+\w+\s+\d+\s+-\s+\d+:\d+//s;
    $this->assert_matches(qr/^\s*$/, $t);
    $this->assert_equals(0, scalar(@mails));
}

sub testOnErrorReplyDelete {
    my $this = shift;
    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.$this->{test_topic}\@example.com
Subject: $this->{test_web}.NotHere
From: notauser\@example.com

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'to';
    $box->{onError} = 'reply delete';
    my $c = $this->cron();
    $this->assert_equals(1, scalar(@mails));
}

sub testOnSuccessReplyDelete {
    my $this = shift;
    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.$this->{test_topic}\@example.com
Subject: $this->{test_web}.NotHere
From: mole\@hill

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'to';
    $box->{topicPath} = 'to';
    $box->{onSuccess} = 'reply delete';
    my $c = $this->cron();
    $this->assert_null($c->{error});
    $this->assert_equals(1, scalar(@mails));
    $this->assert_matches(qr/Thank you for your successful/, $mails[0]);
}

# attachments
sub testAttachments {
    my $this = shift;
    my $mail = <<'HERE';
From - Mon Feb 27 08:40:01 2006
X-Account-Key: account2
X-UIDL: UID7045-1090580229
X-Mozilla-Status: 0013
X-Mozilla-Status2: 10000000
Envelope-to: cc@c-dot.co.uk
Delivery-date: Mon, 27 Feb 2006 08:34:02 +0000
Received: from zproxy.gmail.com ([64.233.162.200])
	  by ptb-mxcore01.plus.net with esmtp (PlusNet MXCore v2.00) id 1FDdpR-0003Rc-JG 
	  for cc@c-dot.co.uk; Mon, 27 Feb 2006 08:34:01 +0000
Received: by zproxy.gmail.com with SMTP id x7so839218nzc
        for <cc@c-dot.co.uk>; Mon, 27 Feb 2006 00:34:00 -0800 (PST)
DomainKey-Signature: a=rsa-sha1; q=dns; c=nofws;
        s=beta; d=gmail.com;
        h=received:message-id:date:from:to:subject:cc:in-reply-to:mime-version:content-type:references;
        b=cxY2+pezI7PttYzGXPgPOekRgntHb6K0YOsnox0cfENpECsDtmx8aD/LQOfp/A2WkCQ0ZE3SEy7j62MALKeca/46SqPYg3PhIKKH03o/4NJC2zsNypKFjH3y0lV1Gy+tOqxUm5Ej2b7TgPGhmRMGWteSl+4Y235naR6WzJUxA4w=
Received: by 10.36.250.68 with SMTP id x68mr626836nzh;
        Mon, 27 Feb 2006 00:33:59 -0800 (PST)
Received: by 10.37.20.51 with HTTP; Mon, 27 Feb 2006 00:33:58 -0800 (PST)
Message-ID: <b293fda70602270033u2665f098l872ecbc52aa8d27e@gmail.com>
Date: Mon, 27 Feb 2006 00:33:58 -0800
From: "Ally Gator" <ally@masai.mara>
To: "Dick Head" <dhead@twiki.com>
Subject: $this->{test_web}.AnotherTopic: attachment test
Cc: another.idiot@twiki.com>
MIME-Version: 1.0
Content-Type: multipart/mixed; 
	boundary="----=_Part_21658_5579231.1141029238540"
References: <b293fda70302260604l31abd8bfu6fc4d5015af21061@mail.gmail.com>

------=_Part_21658_5579231.1141029238540
Content-Type: text/plain; charset=ISO-8859-1
Content-Transfer-Encoding: quoted-printable
Content-Disposition: inline

Message text

------=_Part_21658_5579231.1141029238540
Content-Type: text/plain; name="data.asc"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="data.asc"
X-Attachment-Id: file0

LS0tLS1CRUdJTiBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tClZlcnNpb246IEdudVBHIHYxLjIu
NSAoR05VL0xpbnV4KQoKbVFHaUJFUUN0ajRSQkFDUjAwTjFlSlhZVnNQOVdJUG1paHNwVSswb2ov
a0NIUXBkNmxQT0U5T2RYdW0vczAwUQo4b0kvUFo0WlJHYzI4YUdKTUpzZnZUaENEVkFmcE0zQXUr
SmJMQWR6NVZtdjFXdExReGdyTUI5MjZSaGlsR0FsCmRsQkJvTDhTL1FIZzNBZGpreDlrSVJxWUto
ZGpjODJLbGcvYm1LUnpxalMxZzJiaHhvVDB4emRTa3dDZzJhdk4KaE9DTG1UU3lwd2xhTUxVTUJ4
YjlUdFVELzF0L1BsOHgydXBzRTVyZXRscDB3K1hDMC9UZ2RHb25uTUh3VUZGSgp4UUEwbEF5WktC
UlpTcFdUYlk3Y0VWYzNXUXJBYW5UMFljWXlkd3BLbFFkVzRNSlAzNDNCbWRNZXNBSTVPcVlBClp6
SXMvNW9QZVFJZnFGcTR2aEVrR3kxbjVXUXFCNEcrNEgwWlBhcXVtK2ZqOHUzbjc0cUx5Vit2ODlS
UnpEUjEKVmtOckEvOWZTejVxTVh1aHU4TUZwcTdwYWlYSURLRk9TUWNWYUVkN1ozMDgxU3NTRzYv
SVBBbENCKzQ5SnJJLwpmRXBPU0piQ0VTTjhacVZXWDg1MHdLbzZ6RDN4QnByZUlCamVsQTZjaW9T
OG93ZFRKcDBWVmFFMmZoMWpFS3dOCmlFVzF2OTh2WFBFZ2FuVE0vNDNORlpSbmxlc0l4eVBZRU8z
UjNXTWw5Q1J6bi93dVNiUWdWMmxzYkNCT2IzSnkKYVhNZ1BIZGlibTl5Y21selFHZHRZV2xzTG1O
dmJUNklXd1FURVFJQUd3VUNSQUsyUGdZTENRZ0hBd0lERlFJRApBeFlDQVFJZUFRSVhnQUFLQ1JD
K1ZRc1ZvckxFR0tyTUFLQ2hHWHd5VTRaR1pNdGFlWHJuZDBtVW53eThqUUNmCmR2cTJwb1dzMEp1
WXlWWWJ2YjY3Qk1VaXFDaTVCQTBFUkFLNExCQVFBTmRzYnBmaHVpY2RyVXNYTWFxWWJISU8KYzJn
WDhNaVpqczYxT3llRkhhSE81a2pGQVhpZW9McFBDZm5va3NVYlpPMDVHaUVPQmZMdFY0eEc0Mnlo
NlVzNAo1R2o1WjZ5K1FYQTlLdWQ4UTBEZWlNQTN6b0tkeitFOUJRT2tkY1dPSlNjNVNHcXl1ZjRa
bW5jREp0QzJEWkIyCjdlWUhwSFpBem53UGkzemxCcnhpV0ZRbmJtL2l6Z2N5SmFNU1pDTlFYeTdz
Y09BeWJjd2tENnBnQkUrdWFwYmMKbTcyVXVmSVN3TU5yRmJ1ZnFFWGtsVVRzNjBqdnd5Y1AyRHhx
dTdJZXZ6NXc5WHp0NzlnZW5Mbi9RcXNZbFY5Vwo4eFF0OUY5SllUWndKTW41blkwRWpjdXdhR1Bj
cnNEcEtQQnp3R2xKWkNWdGx2VjU3cDZveHZHdkZENk51R1MzCkZlMTE3R0tvdm9CT3JzYVNERk5y
T0poMnZNemFWYlAzd2ZBMlFzR1AyNjg2bExiK3NpL1hlUkI3QXhZWVEzNjQKQTBjNjYzR3B6K29z
YlM3RWFZbWNiemxsbjZsL1A5R25rZDBOQUU5cjNOQmk5M3RiRlJtZG5qYW9kUHRkZ1BETgpZZFhk
OWdUN3FKcDV5aklkaG1YWURmQWU2WXNBTnV1enVMM0dHWTB1Qkk5M0ltalowWXJSQ0NubWNvc1Bv
aFpwCmljN2R1MTVQbnJwT1ZuempOSnFYYk9KdUdZZzl2Q1gwM2tndGxJUEhGYm90aG5QTlB2dm83
eXkyUC9RV2toYUoKeXhFUzBnY2JxVGtTZVF3RTVXSDA1dUV1RXdqY0JsU2VvY1duMThFMjJjQnpP
ZEdTM3ZXYkRpbVkrREo3TVh4TgpkM0NNSlZad1E1L0ZreXNKMEhTREFBTUdELzkrZ0hyalpIUVJL
TVgxajQyUTloWUluM3hzREFYSnkwK2UxTkRTCmVaVmNDclpGazBmVUYzMXR2aXlPTVBHTDZnTkF5
Y3lNWXdESklWbUg0TUcra1NBeVlyN0J2bVY0RllMUjdiVDIKMndNYStsV2F5aUpPWHRJTVpZQTBv
c3JhenJNUzdLVEUyTGJBQ1NLbnFURGZJRkpIVUJtam02UEZqQUFqWjJENQpaR0NHUlZiWldwa3NZ
bUd5OW1qSTQ0RStqa1kyczJpSEgvRER5QTVTajl1SUExYnpPUHVzbHlQZEtITkpXN1IrCnE4bnZG
VmtHamQ2eXhaRnpHUmdGODRYNFdSRGdsSGVtbEVXTzRWUlJ2dUNJTDZxR3VySGVOenJuaFg1WFM0
amwKVlFtd0dRVVNBWURZdXJiTUNuZG5xMjJWKy9td2RuWmxPTmYwNzRreFlJajI5enFrZlQwWWhK
bFlVTFY0SHA2VQpJbUp3OWdRTTlyaEp4NGFIc3l6K2lIYm15bG0rWXpsdDFDdVBUSnJsZTFWeEwz
TzV3RXlnUXRSeTI4aFB5dWJMClVWVVNBNjhxbDZ5bXhIV1pzZGdLemtmWktRMmdTQnZUaEdJZi9V
cnZvOU41OVlaWE0vWGU4Y1ZoeC9JTjNKRXQKcm9WTjVNR3pLR0VYZGMyK1lQcjlBdW01WG8ycXlK
bnF4NGxiamxNVWQvL3FvSUIwYXE3U2hpWndxamJDcG1CeAo2SlNiSC9KYjY2N0JJdm1vTlhxUTNQ
TGRjTkFBQ1hjZWk0bDIvSHNpeDZ0WEphTJUxNkJFT2lQNXFXUjlJY0ROCnRZTGhkMXk5Q1k1c3Ar
NDVCaGxYaXk2d3VzZG1LOHFybEowcURNdDFHMFJkVHJNNFh2N1p1QVhwR3hUaEc0bTIKdHZ1b1hv
aEdCQmdSQWdBR0JRSkVBcmdzQUFvSkVMNVZDeFdpc3NRWUsyd0FvSkd1aUQyTW1qRnpHU29IUGNj
YQp0RjZMQXNIcUFLQ0VPZmxQTllrYXlTVllMVkNGdzBMZnhIQytidz09Cj0rSi84Ci0tLS0tRU5E
IFBHUCBQVUJMSUMgS0VZIEJMT0NLLS0tLS0K
------=_Part_21658_5579231.1141029238540--
HERE
    $mail =~ s/\$this->{test_web}/$this->{test_web}/g;
    $this->sendTestMail($mail);
    $box->{topicPath} = 'subject';
    $box->{onError} = 'reply';
    $box->{onSuccess} = 'reply';
    my $c = $this->cron();

    $this->assert_equals(1, scalar(@mails));
    $this->assert_matches(qr/Thank you for your successful/, $mails[0]);

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},'AnotherTopic');
    my @a = $m->get('FILEATTACHMENT');
    $this->assert_equals(1, scalar(@a));
    $this->assert_str_equals("data.asc", $a[0]->{attachment});

    $this->assert(-e "$TWiki::cfg{PubDir}/$this->{test_web}/AnotherTopic/data.asc");
}

# templates

sub testUserTemplate {
    my $this = shift;
    my $mail = <<HERE;
Message-ID: message1
Reply-To: sender1\@example.com
To: $this->{test_web}.TargetTopic\@example.com
Subject: Object
From: mole\@hill

Message 1 text here
HERE
    $this->sendTestMail($mail);
    $box->{topicPath} = 'to';
    $box->{onSuccess} = 'reply delete';
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $TWiki::cfg{SystemWebName},
        'MailInContribUserTemplate', <<'HERE');
%TMPL:DEF{MAILIN:wierd}%
Subject: %SUBJECT%
Body: %TEXT%
%TMPL:END%
HERE

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TargetTopic', <<'HERE');
BEGIN
<!--MAIL{template="wierd" where="above"}-->
END
HERE
    my $c = $this->cron();
    $this->assert_null($c->{error});
    $this->assert_equals(1, scalar(@mails));
    $this->assert_matches(qr/Thank you for your successful/, $mails[0]);

    my( $m, $t ) = TWiki::Func::readTopic($this->{test_web},'TargetTopic');

    $this->assert_matches(qr/BEGIN\s*Subject: Object\s*Body: Message 1 text here\s*<!--MAIL{/s, $t);
}

1;
