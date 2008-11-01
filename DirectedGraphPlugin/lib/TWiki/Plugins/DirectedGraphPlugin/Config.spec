# ---+ Directed Graph Plugin 
# Settings for the GraphViz interface.  Generates graphs using the &lt;dot&gt; language
# **PATH M**
# Path to the GraphViz executable. (Must include trailing slash)
$TWiki::cfg{DirectedGraphPlugin}{enginePath} = '/usr/bin/';
# **PATH M**
# Path to the ImageMagick convert utility. (Must include trailing slash) <br>
#   -  This is used to support antialias output <br> 
#      (Required if GraphViz doesn't have Cario rendering support.)
$TWiki::cfg{DirectedGraphPlugin}{magickPath} = '/usr/bin/';
# **PATH M**
# Path to the TWiki tools directory .(Must include trailing slash) <br>
# The DirectedGraphPlugin.pl helper script is found in this directory.
# Typically found in the web server root along with bin, data, pub, etc.
$TWiki::cfg{DirectedGraphPlugin}{toolsPath} = $TWiki::cfg{PubDir}/../tools ;
# **PATH M**
# Perl command used on this system <br>
#  On many systems this can just be the "perl" command
$TWiki::cfg{DirectedGraphPlugin}{perlCmd} = '/usr/bin/perl';
# **PATH**
# Path for plugin to store generated attachments<br>
#  Optional.  If not provided, plugin will manage attachments using the standard TWiki attachment functions.
#  If set to the /pub path, generated attachments will be invisible to TWiki topics.
#  This directory must be web readable.
$TWiki::cfg{DirectedGraphPlugin}{attachPath} = '';
# **PATH**
# URL Path for generated attachments <br>
#  Optional.  Only required if attachPath is not the TWiki pubDir. 
# If not provided, plugin will use the pub directory for linking to attachments.
# If the attachPath is not provided, then this parameter will be ignored.
$TWiki::cfg{DirectedGraphPlugin}{attachUrlPath} = '';

