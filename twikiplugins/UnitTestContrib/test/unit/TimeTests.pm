# tests for TWiki::Time

package TimeTests;
use base qw( TWikiTestCase );

use strict;
use TWiki::Time;
require POSIX;
use Time::Local;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $ENV{TZ} = 'GMT'; # GMT
    POSIX::tzset();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub showTime {
    my $t = shift;
    my @time = gmtime($t);
    $#time = 5;
    $time[4]++; # month
    $time[5] += 1900;
    return sprintf("%04d:%02d:%02dT%02d:%02d:%02dZ",
                     reverse @time);
}

sub checkTime {
    my ($this, $s, $m, $h, $D, $M, $Y, $str, $dl) = @_;
    $Y -= 1900;
    $M--;
    my $gmt = timegm($s, $m, $h, $D, $M, $Y);
    my $tt = TWiki::Time::parseTime($str, $dl);
    $this->assert_equals($gmt, $tt,
                         showTime($tt).' != '.showTime($gmt).
                           ' '.join(' ', caller));
}

sub test_parseTimeTWiki {
    my $this = shift;
    $this->checkTime(0, 1, 18, 10, 12, 2001, "10 Dec 2001 - 18:01");
    $this->checkTime(0, 0, 0, 10, 12, 2001, "10 Dec 2001");
}

sub test_parseTimeRCS {
    my $this = shift;
    $this->checkTime(2, 1, 18, 2, 12, 2001, "2001/12/2 18:01:02");
    $this->checkTime(3, 2, 1, 2, 12, 2001, "2001.12.2.01.02.03");
    $this->checkTime(0, 59, 21, 2, 12, 2001, "2001/12/2 21:59");
    $this->checkTime(0, 59, 21, 2, 12, 2001, "2001-12-02 21:59");
    $this->checkTime(0, 59, 21, 2, 12, 2001, "2001-12-02 - 21:59");
    $this->checkTime(0, 59, 21, 2, 12, 2001, "2001-12-02.21:59");
    $this->checkTime(0, 59, 23, 2, 12, 1976, "1976.12.2.23.59");
    $this->checkTime(2, 1, 18, 2, 12, 2001, "2001-12-02 18:01:02");
    $this->checkTime(2, 1, 18, 2, 12, 2001, "2001-12-02 - 18:01:02");
    $this->checkTime(2, 1, 18, 2, 12, 2001, "2001-12-02-18:01:02");
    $this->checkTime(2, 1, 18, 2, 12, 2001, "2001-12-02.18:01:02");
}

sub test_parseTimeISO8601 {
    my $this = shift;

    $this->checkTime(0, 0, 0, 4, 2, 1995, "1995-02-04");
    $this->checkTime(0, 0, 0, 1, 2, 1995, "1995-02");
    $this->checkTime(0, 0, 0, 1, 1, 1995, "1995");
    $this->checkTime(7, 59, 20, 3, 7, 1995, "1995-07-03T20:59:07");
    $this->checkTime(0, 59, 23, 3, 7, 1995, "1995-07-03T23:59");
    $this->checkTime(0, 0, 23, 2, 7, 1995, "1995-07-02T23");
    $this->checkTime(7, 59, 5, 2, 7, 1995, "1995-07-02T06:59:07+01:00");
    $this->checkTime(7, 59, 5, 2, 7, 1995, "1995-07-02T06:59:07+01");
    $this->checkTime(7, 59, 6, 2, 7, 1995, "1995-07-02T06:59:07Z");

    $ENV{TZ} = 'Europe/Paris'; # GMT + 1
    POSIX::tzset();
    $this->checkTime(7, 59, 5, 2, 4, 1995, "1995-04-02T06:59:07", 1);
    $this->checkTime(7, 59, 6, 2, 4, 1995, "1995-04-02T06:59:07Z", 1);

}

sub test_parseTimeLocal {
    my $this = shift;
    $ENV{TZ} = 'Australia/Lindeman';
    POSIX::tzset();
    $this->checkTime(13, 9, 16, 7, 11, 2006, "2006-11-08T02:09:13", 1);
    # Ensure TZ specifier in string overrides parameter
    $this->checkTime(46, 25, 14, 7, 11, 2006, "2006-11-07T14:25:46Z", 1);
}

1;
