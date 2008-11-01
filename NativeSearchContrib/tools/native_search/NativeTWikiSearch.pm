# Copyright (C) 2007 WikiRing http://wikiring.com All Rights Reserved
# Author: Crawford Currie
# Perl interface to NativeTWikiSearch xs module
package NativeTWikiSearch;

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw( cgrep );

bootstrap NativeTWikiSearch;

1;
