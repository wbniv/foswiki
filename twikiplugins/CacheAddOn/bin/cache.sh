#!/bin/ksh
#
# @(#)$Id: cache.sh 4835 2003-05-19 21:08:57Z pklausner $ GNU (C) by Peter Klausner 2003
#
# NAME:
#	cache - quick'n dirty page caching for TWiki
#
# SYNOPSIS:
#	Identical to TWiki's view
#
# DESCRIPTION:
#	Rename original view to render
#	Link this to 'view'
#
# SEE ALSO:
#	TWiki:Plugins/CacheAddOn  view  fresh
#

# customize...
data=/var/twiki/data
cache=/var/twiki/cache

# debug...
# exec 2> /tmp/twiki.view.log
# set -x

entry="$cache$PATH_INFO?$QUERY_STRING"

#test -d "$entry"	&& entry="$entry/WebHome."

if [ "$entry" -nt "$data/$PATH_INFO.txt" ]
then
	exec cat "$entry"
else
	exec ./render "$@" | tee "$entry" 2>/dev/null
fi
