#!/usr/bin/perl -w
#
#
use strict;
use XML::Simple;
use UNIVERSAL 'isa';

my $xml = XMLin('412to420svn.log');



my %files = ();
my %authors = ();
my %aggregate = ();

#TODO: this will not deal with nested includes
my @plugins = qw/BehaviourContrib ClassicSkin CommentPlugin EditTablePlugin EmptyPlugin InterwikiPlugin JSCalendarContrib MailerContrib PatternSkin PreferencesPlugin RenderListPlugin SlideShowPlugin SmiliesPlugin SpreadSheetPlugin TablePlugin TipsContrib TinyMCEPlugin TWikiUserMappingContrib TwistyContrib TwistyPlugin WysiwygPlugin/;
#add the not released, but required plugins here.
push @plugins, 'UnitTestContrib';

my @agregateBy = qw!data templates/!;
#my @agregateBy = qw!bin data lib locale templates tools working/!;
#unshift @agregateBy, map( {'twikiplugins/'.$_} @plugins);


my $logindex = 0;
while (defined($xml->{logentry}->[$logindex])) {
    my $logentry = $xml->{logentry}->[$logindex];
    unless (defined($authors{$logentry->{author}})) {
        $authors{$logentry->{author}} = ();
        $authors{$logentry->{author}}{commitcount} = 0;
        $authors{$logentry->{author}}{files} = ();
    }
    $authors{$logentry->{author}}{commitcount}++;

    my @paths = $logentry->{paths}->{path};
    if (!isa(($paths[0], 'ARRAY'))) {
        #if there is only one file changed, XML::Simple (sensibly) does not make an array out of it
        @paths = [@paths];
    }

    my $pathindex = 0;
    while (($paths[0][$pathindex])) {
    #for (my $pathindex = 0;$pathindex < $#paths;$pathindex++) {
        my $pathentry = $paths[0][$pathindex];
        my $filePath = $pathentry->{content};
        # shorten the output
        $filePath =~ s|/twiki/branches/MAIN||;
        #print "    $filePath \n";
        
        unless (defined($files{$filePath})) {
            $files{$filePath} = ();
            $files{$filePath}{commitcount} = 0;
            $files{$filePath}{author} = ();
        }
        $files{$filePath}{commitcount}++;
        unless (defined($files{$filePath}{author}{$logentry->{author}})) {
            $files{$filePath}{author}{$logentry->{author}} = 0;
        }
        $files{$filePath}{author}{$logentry->{author}}++;

        #agregate by more general categories of files
        my $aggKey = "other";
        #only show files _in_ release
        if (inRelease($filePath)) {
            foreach my $a (@agregateBy) {
                if ($filePath =~ /$a/ ) {
                    $aggKey = $a;
                    last;
                }
            }
        } else {
            $aggKey = 'Plugins not in Release (not in Stats)';
        }
        unless (defined($aggregate{$aggKey})) {
            $aggregate{$aggKey} = ();
            $aggregate{$aggKey}{commitcount} = 0;
            $aggregate{$aggKey}{author} = ();
        }
        $aggregate{$aggKey}{commitcount}++;
        unless (defined($aggregate{$aggKey}{author}{$logentry->{author}})) {
            $aggregate{$aggKey}{author}{$logentry->{author}} = 0;
        }
        $aggregate{$aggKey}{author}{$logentry->{author}}++;
        
        #files modified by author
        unless (defined($authors{$logentry->{author}}{files}{$filePath})) {
            $authors{$logentry->{author}}{files}{$filePath} = 0;
        }
        $authors{$logentry->{author}}{files}{$filePath}++;
  
        $pathindex++;
    }
    
    $logindex++;
}

#TODO: get rev to&from from log!
print "aggregated TWiki commit statistics from MAIN branch -r13046:16210 (counting number of times a file was changed)\n";
print "note that this is biased heavily towards commiters that have many small files\n\n";
printByAggregate();
print "\n\n";




sub inRelease {
    my $file = shift;
    
    #TODO:
    if ($file =~ /\/twikiplugins\/([^\/\\]*)/) {
        my $pluginName = $1;
        return 0 unless (grep(/$pluginName/, @plugins));
    }
    return 1;
}

sub printByAuthor {
my $authorCount = 0;
    print "===================================\n";
    foreach my $author (keys %authors) {
        print "$author\n";
        my %filelist = %{$authors{$author}{files}};
        my $commitCount = 0;
        my $fileCount = 0;
        foreach my $file (sort keys %filelist) {
            #only show files _in_ release
            next unless (inRelease($file));
        
            print "\t\t $filelist{$file}\t$file \n";
            $commitCount += $filelist{$file};
            $fileCount++;
        }
        $authorCount++;
        print "\t\t ( $commitCount commits to $fileCount core files )\n";
    }
    
    print "$authorCount authors \n";
}

sub printByFile {
my $fileCount = 0;
my %totalAuthors = ();
    print "===================================\n";
    my @fileList = sort(keys %files);
    foreach my $file (@fileList) {
        #only show files _in_ release
        next unless (inRelease($file));

        print "$file\n";
        my %authorlist = %{$files{$file}{author}};
        my $commitCount = 0;
        my $authorCount = 0;
        foreach my $author (sort {$authorlist{$b} <=> $authorlist{$a}} keys %authorlist) {
            print "\t\t $authorlist{$author}\t$author\n";
            $commitCount += $authorlist{$author};
            $authorCount++;
            unless (defined($totalAuthors{$author})) {
                $totalAuthors{$author} = 0;
            }
            $totalAuthors{$author}++;
        }
        
        $fileCount++;
        print "\t\t ( $commitCount commits by $authorCount authors )\n";
    }
    my @aaa = keys(%totalAuthors);
    print "$fileCount files changed by ".(1+$#aaa)." authors\n";
    print "\t".join(', ', map {'TWiki:Main.'.$_." ($totalAuthors{$_} files)"} sort({$totalAuthors{$b} <=> $totalAuthors{$a}} @aaa))."\n";

}

sub printByAggregate {
my $fileCount = 0;
my %totalAuthors = ();
    print "===================================\n";
    my @fileList = sort(keys %aggregate);
    foreach my $file (@fileList) {
        print "---++ $file\n";
        my %authorlist = %{$aggregate{$file}{author}};
        my $commitCount = 0;
        my $authorCount = 0;
        my @output = ();
        foreach my $author (sort {$authorlist{$b} <=> $authorlist{$a}} keys %authorlist) {
            print "   * TWiki:Main.$author ($authorlist{$author})\n";
            $commitCount += $authorlist{$author};
            $authorCount++;
            unless ($file eq 'Plugins not in Release (not in Stats)') {
                unless (defined($totalAuthors{$author})) {
                    $totalAuthors{$author} = 0;
                }
                $totalAuthors{$author} += $authorlist{$author};
                $fileCount += $authorlist{$author};
            }
        }

        print "   * ( $commitCount changes by $authorCount authors )\n";
    }
    my @aaa = keys(%totalAuthors);
    print "---+++ $fileCount changes by ".(1+$#aaa)." authors\n";
    print join("\n", map {'   * TWiki:Main.'.$_." ($totalAuthors{$_})"} sort({$totalAuthors{$b} <=> $totalAuthors{$a}} @aaa))."\n";

}

