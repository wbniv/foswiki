=pod

Monitoring package. Instrument the code like this:

use Monitor;
Monitor::MARK("Description of event");
Monitor::MARK("Another event");

or, to monitor all the calls to a module

use Monitor;
Monitor::MonitorMethod('TWiki::Users');

or a function

use Monitor;
Monitor::MonitorMethod('TWiki::Users', 'getCanonicalUserID');

Then set the environment variable TWIKI_MONITOR to a perl true value, and
run the script from the command line e.g:
$ cd bin
$ ./view -topic Myweb/MyTestTopic

The results will be printed to STDERR at the end of the run. Two times are
shown, a time relative to the last MARK and a time relative to the first MARK
(which is always set the first time this package is used). The final column
is total memory.

NOTE: it uses /proc - so its linux specific...

=cut



package Monitor;

use strict;

use vars qw(@times @methodStats);

sub get_stat_info {
    # open and read the main stat file
    if( ! open(_INFO,"</proc/$_[0]/stat") ){
        # Failed
        return { vsize=> 0, rss => 0 };
    }
    my @info = split(/\s+/,<_INFO>);
    close(_INFO);

    # these are all the props (skip some)
    # pid(0) comm(1) state ppid pgrp session tty
    # tpgid(7) flags minflt cminflt majflt cmajflt
    # utime(13) stime cutime cstime counter
    # priority(18) timeout itrealvalue starttime vsize rss
    # rlim(24) startcode endcode startstack kstkesp kstkeip
    # signal(30) blocked sigignore sigcatch wchan

    # get the important ones
    return { vsize  => $info[22],
             rss    => $info[23] * 4};
}

sub mark {
    my $stat = get_stat_info($$);
    push(@times, [ shift, new Benchmark(), $stat ]);
}

BEGIN {
    my $caller = caller;
    if ($ENV{TWIKI_MONITOR}) {
        require Benchmark;
        import Benchmark ':hireswallclock';
        die $@ if $@;
        *MARK = \&mark;
        *MonitorMethod = \&_monitorMethod;
        MARK('START');
    } else {
        *MARK = sub {};
        *MonitorMethod = sub {};
    }
}

sub tidytime {
    my ($a, $b) = @_;
    my $s = timestr(timediff($a, $b));
    $s =~ s/\( [\d.]+ usr.*=\s*([\d.]+ CPU)\)/$1/;
    $s =~ s/wallclock secs/wall/g;
    return $s;
}

sub END {
    return unless ($ENV{TWIKI_MONITOR});
    MARK('END');
    my $lastbm;
    my $firstbm;
    my %mash;
#    foreach my $bm (@times) {
#        $firstbm = $bm unless $firstbm;
#        if ($lastbm) {
#            my $s = tidytime($bm->[1], $lastbm->[1]);
#            my $t = tidytime($bm->[1], $firstbm->[1]);
#            $s = "\n| $bm->[0] | $s | $t | $bm->[2]->{vsize} |";
#            print STDERR $s;
#        }
#        $lastbm = $bm;
#    }
	my %methods;
	foreach my $call (@methodStats) {
		$methods{$call->{method}} = {count=>0,min=>99999999,max=>0} unless defined($methods{$call->{method}} );
		$methods{$call->{method}}{count} +=1;
		my $diff = timediff($call->{out}, $call->{in});
		#my $diff = $call->{out}{rss} - $call->{in}{rss};
		$methods{$call->{method}}{min} = ${$diff}[0] if ($methods{$call->{method}}{min} > ${$diff}[0]);
		$methods{$call->{method}}{max} = ${$diff}[0] if ($methods{$call->{method}}{max} < ${$diff}[0]);
		if (defined($methods{$call->{method}}{total})) {
			$methods{$call->{method}}{total} = Benchmark::timesum($methods{$call->{method}}{total}, $diff);
		} else {
			$methods{$call->{method}}{total} = $diff;
		}
	}
	print STDERR "\n| Count  |  Min   |  Max   | Total      | Method |";
	foreach my $method (sort keys %methods) {
		print STDERR "\n| "
			.sprintf('%6u', $methods{$method}{count}).' | '
			.sprintf('%6.3f', $methods{$method}{min}).' | '
            .sprintf('%6.3f', $methods{$method}{max}).' | '
			.timestr($methods{$method}{total})." | $method |";
	}
    print STDERR "\n";
}

#BEWARE - though this is extremely useful to show whats fast / slow in a Class, its also a potentially 
#deadly hack
#method wrapper - http://chainsawblues.vox.com/library/posts/page/1/
sub _monitorMethod {
	my ($package, $method) = @_;
	
	if (!defined($method)) {
		no strict "refs";
		foreach my $symname (sort keys %{"${package}::"}) {
			next if ($symname =~ /^ASSERT/ );
			next if ($symname =~ /^DEBUG/ );
			next if ($symname =~ /^UNTAINTED/ );
			next if ($symname =~ /^except/ );
			next if ($symname =~ /^otherwise/ );
			next if ($symname =~ /^finally/ );
			next if ($symname =~ /^try/ );
			next if ($symname =~ /^with/ );
			_monitorMethod($package, $symname);
		}
	} else {
		my $old =  ($package)->can($method); # look up along MRO
		return if (!defined($old));
		#print STDERR "monitoring $package :: $method)";
		{
			no warnings 'redefine';
			no strict "refs";
			*{"${package}::$method"} = sub {
				#Monitor::MARK("begin $package $method");
				my $in_stat = get_stat_info($$);
				my $in_bench = new Benchmark();
				my $self = shift;
				my @result = $self->$old(@_);
				my $out_bench = new Benchmark();
				#Monitor::MARK("end   $package $method  => ".($result||'undef'));
				my $out_stat = get_stat_info($$);
    			push(@methodStats, {method=> "${package}::$method", in=>$in_bench, in_stat=>$in_stat, out=>$out_bench, out_stat=>$out_stat });
				return wantarray ? @result : $result[0];
			}
		}
	}
}

1;
