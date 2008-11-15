---+ TWPC, aka theTWiki Public Cache
Colas Nahaboo http://colas.nahaboo.net
This readme is a "under the hood" work document. The official page is at
http://twiki.org/cgi-bin/view/TWiki/PublicCacheAddOn

Files:
   * pccr Cache Reader, shell version. Slower
   * pccr.c C version for speed 
   * pcbd Cache Builder, called by pccr on cache misses
   * pccl Cache Cleaner, run by crontab to clear cache after edits
   * pcad ADmin commands, web based
   * pcal Log analyzer to determine best settings of twpc from past usage
     (not yet written)
   * pcge script to build all pages, called by pcad
   * PublicCacheAddOn.txt  User/admin Documentation as a twiki page
   * PublicCachePlugin.pm PublicCachePlugin.txt perl module to trigger cache
     invalidation on topic change
   * README_TWPC.txt this file, internal dev info
   * install uninstall make-pc-config: installation management
   * make-distrib make-hg-revision: build system for dev
Generated files by install:
   * vief is a copy of the original TWiki bin/view used to build cached pages
     bin/view is replaced bin pccr.
     a backup is made in pc-view-backup, just in case...
   * pccr.bin
   * pc-config a "compilation" of lib/LocalSite.cfg settings
   * pc-options keep track of last used options on install

Cache files:
   * cache resides in working/public_cache/cache
   * inside, there are one folder per web, same name
   * and files with radix the topic name, and extensions:
      * .tx    uncompressed plain version (including CGI HTTP header)
      * .gz    same, compressed (including CGI HTTP header)
      * .nc    nocache: do not attempt to cache it
      * .lk    lock file: the cache is being (re)built by a process
   * at cache root, directory _tmp holds temporary files used to build caches
     in named process_id + extensions:
      * .raw   raw output of TWiki, then uncompressed cache
      * .mod   modified output
      * .gz    compressed cache
   * at cache root, directory _changers contains the IPs (one file per IP,
     named as the IP) of editors. The file has the modification time of last 
     edit
   * at cache root, directory _expire contains web/topic empty files whose
     date indicates the time at which the cache should be removed by pccl 
     for this page (the file have thus a date in the close future)
   * cache clear is done by moving cache into cache.a_number, and removing it
     30 seconds after, to avoid race conditions and errors that removing a
     directory under the feet of build processes could cause

Log files:
   * in the same dir as twiki log files (data/)
   * if -q was not given, logs cache hits in the normal twiki logs
     with user agent cached,gzip or cached
   * twpc-debug.txt logs lots of misc info for debug, only in -v was 
     specified on install
   * twpc-warnings.txt logs abnormal, but not fatal, conditions:
     * LOCK_TIMEOUT pcbd waited to long and decided to break log
     * LOCK_MISSING some race condition occurred
     * NOT_BUILT_ERR building attemp resulted in an error other than 
       access denied

In case of twpc update:
   * if view is pccr, that means we have a working twpc install
      * we copy all files
   * if no pccr file, or view is not pccr, we have a normal/updated twiki
      * we copy all files, mv view to vief, copy pccr to view

Debug messages tracing various steps in data/twpc-debug.txt: (warning: this
list is obsolete)
   * HIT file: cache hit (HIT_GZ for gzipped)
   * BYPASS_QS url: cache ignored as we have a query string ?x=y in url
   * BYPASS_NC url: cache ignored as url was marked as not cacheable
        (protected?)
   * BUILT url: cache build for url
   * NOT_BUILT_ERR url: error in getting URL, marking it as not cacheable
   * NOT_BUILT_AUTH url: URL read-protected, marking it as not cacheable
   * WAITED n url: waited n seconds for a previous build
   * MISS: cache miss, followed by either BUILT or NOT_BUILT
   * WAIT id n url: waits for lock for n seconds

ISSUES:
   * in a pccr web request, we may end up calling another url on same TWiki
     by wget: we could thus deadlock the server if all
     the requests are stuck this way. 
     Advise user to raise the number of apache children. However, this should
     never happen in actual cases, and anyway apache will timeout eventually.
   * link in view to edit?t=%GMTIME{"$epoch"} would normally render the pages
     uncachables (would get dirty each second). but it appears that browsers
     do not cache as soon as there is a query string so we dont care
     to provide this functionality
   * install/update/uninstall clears the whole cache, we don't try to
     determine the ones that really are dirty. better safe than sorry.

TESTS:
with --compressed will use gzip

i=1000;while let 'i-->0';do curl --compressed -s http://wikidev.nahaboo.org/System/Macros >/dev/null& done

PCCR ALGORITHM VERSIONS
   * v1 header is in file. tries in order ?query, .gz, .tx, .nc
   * v2 when editing our IP is marked as a "changer"
      * views from this IP bypasses cache
      * after a timeout "cleargrace" (default 17 mn) with no more edit from
        this IP, cache is reset, if all editors have also not edited for
	at least "cleargracemin" (default 3mn)
   * v3 introduced the PCACHEEXPTIME TWiki tag
   * v4 used the PUBLIC_CACHE_EXPIRE TWiki var

TODO:
   * should work on sites with .pl extensions
   * pcbd could cd to cache first, to avoid half building things if a cache
     clear happens in mid-build
   * pcad clear should be callable from cli, 
      * Plugin should use it directly, optionally use wget for mod_perl
      * scripts could call it to trigger a change (write) e.g. blog-generate
   * document how other modules/scripts could use the cache
   * pcge -v should not list private pages?
   * just after login we are redirected to vief
   * detailed stats: 
      * logs, uncacheable pages, expires. some terse stats moved in menu
      * stats menu then holds more detailed stats: stats per web
     decoding it from wget
   * make-distrib should
      * commit in SVN
      * deploy Todo & Implementation ,txt pages as wiki pages
   * pcal, log analysis
   * option -s space-efficient: only store gzipped version, unzip on the
     demand. For C, use zlib to inflate.
   * generational cache: if we know we are doomed, where to build new pages?
     in the new cache?
     A solution: 
      * pccr: if a changer use cache=cache_changers, including pcbd calls
      * plugin: on write, clear cache_changers, create a new 
      * on changers expire, clear cache, mv cache_changers as cache
   * pcad command to clean all cache pages older than ...
   * C version: make 2 versions, one checking for changer IP and one not
     make PublicCachePlugin install the first, and cache clear the 2nd
     variant: change a byte in executable binary

MAYBE TODO:
   * ? see if we can get the mime-type header from the View.pm patch instead of
   * ? option for let logged people passthrough cache (how to detect them?)
   * ? put twpc files into a dir other than bin/? cgi/? (but what about view?)
   * ? optional expire header
   * ? background crawling process to add & refresh an expire header to the
       cached pages, for the "ok now the site is final" moment
   * ? make an apache-based pccr, with rewite rules? see:
      * http://mail-archives.apache.org/mod_mbox/httpd-users/200701.mbox/%3C1C80FD8A7D2B2745B0396F4D2D0565B401AE4C6D@apwmsg01.alc.ca%3E
   * ? make a proper generic TrackChangesPlugin and use it: can call hooks,
       logs unix style: linenum isodate who action web.topic IP [attachment]
       list all actions (call to writeLog). convert script. per day?
   * ? check we could force cache in one language / localisation?
   * ? cache directive in html comments in pages? (to set Expire per page)

