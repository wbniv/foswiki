CFLAGS = -DSTANDALONE @CFLAGS@ @WARNS@
LDADD=libtdb.la

if BUILD_TDBTEST
TDBTEST = tdbtest
else
TDBTEST =
endif

if BUILD_TDBTORTURE
TDBTORTURE = tdbtorture
else
TDBTORTURE =
endif

noinst_PROGRAMS=tdbspeed tdbiterate $(TDBTEST) $(TDBTORTURE)
bin_PROGRAMS=tdbtool tdbdump

lib_LTLIBRARIES=libtdb.la

include_HEADERS=tdb.h
libtdb_la_SOURCES=tdb.c spinlock.c spinlock.h
libtdb_la_LDFLAGS= -version-info 1:0:0

tdbtest_SOURCES=tdbtest.c
tdbspeed_SOURCES=tdbspeed.c
tdbtest_LDFLAGS=-lgdbm
tdbtool_SOURCES=tdbtool.c
tdbtorture_SOURCES=tdbtorture.c
tdbtorture_LDFLAGS=-ldl
tdbiterate_SOURCES=tdbiterate.c
tdbdump_SOURCES=tdbdump.c

man_MANS=tdb_close.3 tdb_delete.3 tdb_error.3 tdb_exists.3 tdb_fetch.3 \
	tdb_firstkey.3 tdb_open.3 tdb_store.3 tdb_traverse.3 tdb_chainlock.3 \
	tdb.3

EXTRA_DIST=$(man_MANS) tdb.spec
