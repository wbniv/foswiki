#! perl -w
use strict;
use Data::Dumper;
use File::Path;

# (C) Martin Cleaver 2005
# This may be distributed in the same terms as Perl itself.

# Although protocol is a config option, the script assumes ssh

my $configFile = 'unisonsync.cfg';
require $configFile;

#print Dumper($UnisonSync::options);
die "No options hashref set" unless ($UnisonSync::options); 
# SMELL: should check for the options I am looking for

syncTWikiInstall($UnisonSync::options, @ARGV);

sub syncTWikiInstall {
	my ($options, @args) = @_;
	my $accounts = $options->{accounts};
	
	my @accountNames;
	
	if (@args) {
	   @accountNames = @args;
	} else {
	   @accountNames = @{$options->{syncAccounts}};
	}

	print "Syncing Accounts ".join(',', @accountNames)."\n";


	foreach my $accountName (@accountNames) {
		syncAccount($accounts, $accountName, $options);
	}

	print "\n-----\n";
	foreach my $accountName (@accountNames) {
		my $account = $accounts->{$accountName};	
		print $account->{report};
	}
}

sub report {
   my ($account, $text) = @_;
   return unless $text;
   $account->{report} .= $text;
   print $text;
}

sub reportLastOutputs {
   my ($account) = @_;
   local( *FH ) ;

   for my $runOutputType qw(unisonCaptureLog unisonStdErrFile) {
      my $file = $account->{$runOutputType};  
      open( FH, $file) or next; # Error appending contents of $account->{$runOutputFile} 
      my $text = do { local( $/ ) ; <FH> };
      $account->{report} .= "====$runOutputType===\n$text\n===end===\n";
      close FH;
      report($account, "Sweeping $runOutputType ($file) into report and deleting $file\n") if ($account->{debug} > 2);
      if ($account->{debug} > 2) {
        report($account, "Not deleting '$file' as debug is 2 or above\n");
      } else {
	unlink $file; 
      }
   }
}

# if the user wants it as mixed with unison's output we delete it from internal store 
# at the point we write it out.
sub reportFlush {
   my ($account) = @_;
   my $filename = $account->{'unisonLogfile'};
   if ($filename) {
   		my $report = $account->{'report'};
 	    unless (open( FILE, ">>$filename" )) {	
 	    	die "Cannot write report to $filename - $! - log: $report";
 	    	return;
   		};
    	print FILE $report;
	    close(FILE); 
	    $account->{'report'} = ''; # as we've flushed it
   }
}

sub syncAccount {
	my ($accounts, $accountName, $options) = @_;
	my $account = $accounts->{$accountName};
	if (!defined $account) {
		$accounts->{$accountName} = {report=>''};
		report($accounts->{$accountName}, "No such account '$accountName' - skipping\n");
		next;
	}

	report($account, "\n\nSync report:\nAccount: ".$accountName."\n");
	foreach my $key (%$options) {
		my $value = $options->{$key};
		if (!defined $account->{$key}) {
			exposeAttribute($account, $key, $value);
		} else {
			report($account, "Warning: global key $value overridden by local account $accountName value ".$account->{$key}."\n");
		}
	}

	exposeAttribute($account, 'accountName', $accountName);
	my $timestamp = time2str('%Y%m%d-%H%M%S', time());
	exposeAttribute($account, 'timestamp', $timestamp);
        expandAccountVariables($account, 'unisonStdErrFile', 'unisonCaptureLog', 'unisonLogfile');
		
	report($account, "Settings: for $accountName:\n".Dumper($account)."\n") if ($account->{debug} > 2);
	report($account, "Syncing $accountName\n") if ($account->{debug});
	
    writePlinkLauncherScript($account);
    my @webs = @{$account->{webs}};
    foreach my $web (@webs) {
    	syncWeb($account, $web);
    }
	reportFlush($account);
	deletePlinkLauncherScript($account);
}

sub syncWeb {
	my ($account, $web) = @_;
	use Date::Format;
	exposeAttribute($account, 'web', $web);
	syncDir($account, $account->{dataDir}, $web);
	syncDir($account, $account->{pubDir}, $web);
}


sub syncDir {
	my ($account, $dir, $web) = @_;
	exposeAttribute($account, 'dir', $dir);
	report($account, "Web: $web\nDir: $dir\n");

# TODO: test you can set this to '' and have that override separation of webs.
	unless ($account->{clientParentWeb}) {
		$account->{clientParentWeb} = $account->{accountName};
	}
	
    my $optionalClientParentSlash = optionalParentSlash($account->{clientParentWeb});
    my $optionalServerParentSlash = optionalParentSlash($account->{serverParentWeb});

	# SMELL - should not repeat this clientDirAbs
    my $clientDir = $dir.'/'.$optionalClientParentSlash.$web;
    my $clientDirAbs = $account->{clientRoot}.'/'.$clientDir;
    unless (-d $clientDirAbs) {
    	report($account, "Made directory $clientDirAbs\nWARNING: this is a new parent web - you will have to copy in the _default web content so that TWiki can show it properly\n");
    	mkpath $clientDirAbs || report($account, "ERROR: could not make $clientDirAbs\n");
    }
    my $serverDir = $dir.'/'.$optionalServerParentSlash.$web;
	syncFileSet($account, $clientDir, $serverDir);
}

sub syncFileSet {
   my ($account, $clientDir, $serverDir) = @_;

   my $cmd = getSyncFileSetCommand($account, $clientDir, $serverDir);

   report($account, "BEFORE SUBSTITUTIONS:\n".$cmd."\n") if ($account->{debug} > 2);
   $cmd = doSubstitutions($account, $cmd);

   report($account, "AFTER SUBSTITUTIONS:\n".$cmd."\n") if ($account->{debug} > 2);
   report($account, $cmd."\n") if ($account->{debug} > 1);
   unless($account->{dryrun}) {
   	reportFlush();
	system($cmd);
	reportLastOutputs($account);
   } else {
   	   report($account, "dry run, so not executing\n");
   	   report($account, "(turn debug >= 2 to see cmd that would be executed)\n") unless ($account->{debug})
   }
}

sub optionalParentSlash {
   my ($optionalParent) = @_;
    if ($optionalParent) {
    	$optionalParent .= '/';
    } else {
    	$optionalParent = '';
    }  
    return $optionalParent;
}

sub getSyncFileSetCommand {
    my ($account, $clientDir, $serverDir) = @_;    

    my @optionalSshCmd = ();
    my $optionalServerSpec = '';
    if ($account->{serverSite}) {
	$optionalServerSpec = $account->{protocol}.'://'.$account->{serverSite}.'/';
	@optionalSshCmd = ("-sshcmd", $account->{plinkTempLauncherScriptFile});
    }

    my $clientFileSet = $account->{clientRoot}.'/'.$clientDir;
    my $serverFileSet = $optionalServerSpec.$account->{serverRoot}.'/'.$serverDir;

    my @unisonArgs = (@optionalSshCmd, $account->{unisonOptions});

    my $unisonCaptureErrors = $account->{unisonCaptureErrors};
    my @cmd = ($account->{clientUnisonExecutable}, $clientFileSet, $serverFileSet, @unisonArgs, $unisonCaptureErrors);

    return join(' ',@cmd);
}


sub plinkLauncherScriptContents {
	my ($account) = @_;
   return "\@\"$account->{plinkExecutable}\" $account->{serverSite} -i \"$account->{clientServerPrivateKey}\" -l $account->{serverAccount} -ssh $account->{serverUnisonExecutable} -server -contactquietly";
}

=pod
Writes a launcher file specific to the machine you are contacting but independent
of the twiki installations on that machine.

@"c:\program files\putty\plink.exe" mrjc.com -i "c:\Documents and Settings\Marti
n Cleaver\PuttyPrivateKey.ppk" -l mrjc -ssh unison -server -contactquietly
=cut

sub writePlinkLauncherScript {
	my ($account) = @_;
	if ($account->{serverSite}) {
	    open( FILE, ">$account->{plinkTempLauncherScriptFile}" );
    	print FILE plinkLauncherScriptContents($account);
	    close(FILE);    
	}
}

sub deletePlinkLauncherScript {
	my ($account) = @_;
	if ($account->{serverSite}) {
	    unlink $account->{plinkTempLauncherScriptFile} unless ($account->{debug} > 2);
	}
}

# Add to the structure a record of the account (user specifies it on the outside of the hash)
# SMELL - there should be a way of automatically taking the exposed attribute out of scope.
sub exposeAttribute {
	my ($account, $attribute, $value) = @_;
	$account->{$attribute} = $value;
	
	report($account, "Exposed attribute '$attribute' = $value\n") if ($account->{debug} > 2);
}

# SMELL - that I have to expose some variables early seems fishy. Never mind.
sub expandAccountVariables {
   my ($account, @vars) = @_;
   foreach my $var (@vars) {
      my $value = doSubstitutions($account, $account->{$var});
      report($account, "Expanding early the attribute '$var' = $value\n") if ($account->{debug} > 2);
      $account->{$var} = $value;
   }
}

sub doSubstitutions {
 my ($account, $text) = @_;
	foreach my $key (keys %$account) {
		my $value = $account->{$key};
		$text =~ s/%$key%/$value/g if ($value); #SMELL - this needs to be a literal key, e.g. pass key = '{$}'
	}
 return $text;
}