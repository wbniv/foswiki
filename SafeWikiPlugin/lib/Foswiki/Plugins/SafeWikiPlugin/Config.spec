#---+ Security setup
#---++ SafeWikiPlugin
# **PERL**
# Array of perl regular expressions, one of which must match the value
# of an on* handler, or it
# will be filtered. The default permits a simple function call; for
# example:
# <tt>javascript: fn(param1, "param2")</tt>. You can
# use other Foswiki::cfg variables in the the strings here.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeHandler} = ['^(\s*javascript:)?(\s*return)?\s*\w+\s*\(((\w+|\'[^\']*\'|"[^"]*")(\s*,\s*(\w+|\'[^\']*\'|"[^"]*"))*|\s*)?\)[\s;]*(return\s+(\w+|\'[^\']*\'|"[^"]*")[\s;]*)?$'];

# **STRING 30**
# String used to replace dodgy URIs. Can be a URI if you want.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmHandler} = 'alert("Handler filtered by SafeWikiPlugin")';

# **PERL**
# Array of perl regular expressions, one of which must be matched for
# a URI used in a Foswiki page to be passed unfiltered. You can
# use other Foswiki::cfg variables in the the strings here.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeURI} = ['^/','^http://localhost(:.*)?/','^$Foswiki::cfg{DefaultUrlHost}/'];

# **STRING 30**
# String used to replace dodgy URIs. Can be a URI if you want.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmURI} = 'URI filtered by SafeWikiPlugin';

# **BOOLEAN**
# If this is option is enabled, then the plugin will filter *all* URIs, and not
# just those used in SCRIPT tags.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll} = 0;

# **BOOLEAN**
# If this is option is enabled, then the plugin will check HTML for
# correctness. While nowhere near as rigorous as a full XHTML validation,
# this check will at least highlight malformed HTML that might be exploited
# by a hacker.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity} = 0;

