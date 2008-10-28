#!/bin/sh

# the config specifies the spider.pl and spider config
[ ! -d ./indexes ] && mkdir ./indexes
nice /usr/local/bin/swish-e -c twiki-index.config -S prog > \
    ./indexes/twiki-build-index.log 2>&1

