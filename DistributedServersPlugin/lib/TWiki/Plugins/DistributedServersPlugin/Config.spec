# ---+ Extensions
# ---++ DistributedServersPlugin
# **PERL**
# a hash of Wiki URL's that are transformed round robin style to the CDN Url's
# this is most useful for skin files - and should be avoided for any Web's containing 
# secured attachments
$TWiki::cfg{Plugins}{DistributedServersPlugin}{CDNMap} = {
    'http://t42p/trunk/pub/TWiki/' => [
        'http://starfish.nextwiki.org/nextwiki.org/pub/TWiki/'
    ],
    'http://twikifork.org/pub/TWiki/' => [
        'http://starfish.nextwiki.org/nextwiki.org/pub/TWiki/'
    ],
    'http://www.twikifork.org/pub/TWiki/' => [
        'http://starfish.nextwiki.org/nextwiki.org/pub/TWiki/'
    ],
    'http://nextwiki.org/pub/TWiki/' => [
        'http://starfish.nextwiki.org/nextwiki.org/pub/TWiki/'
    ],
    'http://www.nextwiki.org/pub/TWiki/' => [
        'http://starfish.nextwiki.org/nextwiki.org/pub/TWiki/'
    ]
};

1;
