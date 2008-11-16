#
# NextWiki mod_perl DAV handler
# Author: Crawford Currie http://c-dot.co.uk
#
package Apache::NextWikiDAVHandler;

use strict;
use warnings;

use Apache::WebDAV;
use Filesys::Virtual::NextWiki;

sub handler {
     my $r = shift;

     my $dav = new Apache::WebDAV();

     my @handlers = (
         {
             # The URL path we handle
             path   => '/dav', # goes to root_path in the handler::new
             module => 'Filesys::Virtual::NextWiki',
         }
     );

     $dav->register_handlers(@handlers);

     return $dav->process($r);
 }

1;

