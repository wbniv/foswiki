#! /usr/bin/perl -w

use strict;
use FileHandle;
use FileDigest;
use Common;

# TODO: split out the generic from the TWiki-specific parts of this.
package IndexDistributions;

sub indexDistribution {
 use Cwd;

 my ( $distribution, $distributionLocation, $excludeFilePattern, $pathPrefix ) =
   @_;
 use File::Find;
 unless ( defined $pathPrefix ) { $pathPrefix = "" }

 my $preprocessCallback = sub {
  my @ans = grep { !/$excludeFilePattern/ } @_;
  return @ans;
 };

 my $findCallback = sub {
  my $pathname = $File::Find::name;    #  complete pathname to the file.
  Common::debug "$pathname\n";
  my $relativePath =
    Common::relativeFromPathname( $pathname, $distributionLocation );
  return unless includeInResults($relativePath);
  return unless -f $pathname;
  return if -z $pathname;
  Common::debug "$pathname\n";
  indexFile( $distribution, $distributionLocation, $pathname, $pathPrefix,
   $relativePath );
 };
 find(
  {
   wanted     => $findCallback,
   preprocess => $preprocessCallback,
   follow     => 0,
   untaint => 1,
   untaint_skip => 1, 
   no_chdir => 1
  },
  $distributionLocation
 );
}

sub indexFile {
 my ( $distribution, $distributionLocation, $file, $pathPrefix, $relativePath )
   = @_;
 my $digest = digestForFile($file);
 Common::debug $relativePath. " = " . $digest . "\n";
 FileDigest::addOccurance( $distribution, $pathPrefix . $relativePath,
  $digest );
}

sub digestForFile {
 my ($file) = @_;
 my $fh = new FileHandle $file, "r";
 unless ( defined $fh ) {
  return "$!";
 }
 unless ( -s $fh ) {
  return "EMPTY";
 }
 use Digest::MD5;
 my $ctx = Digest::MD5->new;
 $ctx->addfile($fh);
 return $ctx->hexdigest();
}

#---------------------------------------------------
# TWiki-specifics
#---------------------------------------------------
my $runDir;

sub includeInResults {
 my ($relativePath) = @_;

 #CodeSmell: should be able to do this in preprocessCallback
 if (( $relativePath =~ m!.*data/(.*)/! )
  or ( $relativePath =~ m!.*templates/(.*)/! ) 
  or ( $relativePath =~ m!.*pub/(.*)/! ) )
 {
  my $web = $1;

  #	    print "Index web '$web'?" ;
  if ( $web =~ m/$Common::websToIndex$/ ) {
   #		print "yes\n";
   return 1;
  }
  else {
   #		print "no\n";
   return 0;
  }
 }
 return 1;
}

sub indexLocalInstallation {
 my $ans;
 ensureInstallationDir();
 FileDigest::emptyIndexes();
 $ans .=  "Indexing localInstallation '$Common::installationDir'\n";
 IndexDistributions::indexDistribution( "localInstallation", 
					$Common::installationDir, $Common::excludeFilePattern,
					"twiki");

 $ans .= saveIndex("localInstallation.md5");
 return $ans;
 #	print FileDigest::dataOutline();
}

sub indexLocalEmptyDistribution {
    my $ans;
    FileDigest::emptyIndexes();
    $ans .=  "Emptying localInstallation\n";
    $ans .= saveIndex("localInstallation.md5");
    return $ans;
}

sub indexReleases {
 my $inclusionTest = sub {
  my ($download) = @_;
  return 0 unless ( $download =~ m/TWiki[0-9].*/ );
  return 0 if ( $download =~ m/beta/ );
  return 1;
 };

 indexDistributions( $inclusionTest, "releases.md5" );
}

sub indexBetaReleases {
 my $inclusionTest = sub {
  my ($download) = @_;
  return 0 unless ( $download =~ m/TWiki[0-9].*/ );
  return 1 if ( $download =~ m/beta/ );
  return 0;
 };

 indexDistributions( $inclusionTest, "betas.md5" );
}

sub indexPlugins {
 my $inclusionTest = sub {
  my ($download) = @_;
  return 1 unless ( $download =~ m/TWiki.*/ );
  return 0 if ( $download =~ m/TWiki[0-9]/ );
  return 1;    # e.g. TWikiCacheAddOn
 };

 indexDistributions( $inclusionTest, "plugins.md5" );
}

sub getDirsListed {
 my ($dir) = @_;

 use DirHandle;
 my $dh = DirHandle->new($dir) || die "$! - $dir";
 return sort

   #	   grep { -d }
   grep { !/\./ } $dh->read();
}

sub installsOfMine {
 IndexDistributions::indexDistribution( "athens",
  $ENV{HOME} . "/athenstwiki.mrjc.com/",
  $Common::excludeFilePattern );
 IndexDistributions::indexDistribution( "beijing",
  $ENV{HOME} . "/beijingtwiki.mrjc.com/",
  $Common::excludeFilePattern );
 IndexDistributions::indexDistribution( "cairo",
  $ENV{HOME} . "/cairotwiki.mrjc.com/",
  $Common::excludeFilePattern );
}

sub ensureInstallationDir {
 if ( $Common::installationDir eq "" ) {
  die "You must edit TRTConfig to tell it where you've installed TWiki";
 }
# print "$Common::installationDir\n";
}

sub setRunDir {
 ($runDir) = @_;
}

sub indexDistributions {

 # This depends on a modified version of Crawfords' SharedCode
 my ( $filterInSub, $indexName ) = @_;
 my $ans;
 FileDigest::emptyIndexes();
 my $dir = $Common::downloadDir;

 my @downloads = getDirsListed($Common::downloadDir);

 foreach my $download (@downloads) {
  next unless &$filterInSub($download);
  $ans .= "Indexing $download\n";
  IndexDistributions::indexDistribution( $download, $dir . $download,
   $Common::excludeFilePattern, "twiki" );
 }

 $ans .= saveIndex($indexName);
}

sub saveIndex {
 my ($indexName) = @_;
 my $saveFile = $Common::md5IndexDir . $indexName;
 my $ans = "saving to " . File::Spec->rel2abs($saveFile) . "\n";

 FileDigest::saveIndex($saveFile);
 return $ans;
}
1;
