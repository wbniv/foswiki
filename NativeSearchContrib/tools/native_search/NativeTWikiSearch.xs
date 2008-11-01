/* Copyright (C) 2007 WikiRing http://wikiring.com All Rights Reserved
 * Author: Crawford Currie
 * Fast grep function designed for use from Perl. Does not suffer from
 * limitations of `grep` viz. cost of spawning a subprocess, and
 * limits on command-line length.
 */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*
 * Unpack perl args into an array of (read only) strings. The function name
 * is dictated by the mapping in the default typemap i.e.
 * (char** -> T_PACKEDARRAY -> XS_unpack_charPtrPtr
 */
char ** XS_unpack_charPtrPtr(SV* rv) {
	AV *av;
	SV **ssv;
	char **s;
	int avlen;
	int x;

	if (SvROK(rv) && (SvTYPE(SvRV(rv)) == SVt_PVAV))
		av = (AV*)SvRV(rv);
	else {
		warn("unpack_args: rv was not an AV ref");
		return ((char**)NULL);
	}

	/* is it empty? */
	avlen = av_len(av);
	if (avlen < 0){
		warn("unpack_args: array was empty");
		return ((char**)NULL);
	}

	/* av_len+2 == number of strings, plus 1 for an end-of-array sentinel.
	 */
	s = (char **)malloc(sizeof(char*) * (avlen + 2));
	if (s == NULL){
		warn("unpack_args: unable to malloc char**");
		return ((char**)NULL);
	}
	for (x = 0; x <= avlen; ++x){
        s[x] = (char*)NULL;
		ssv = av_fetch(av, x, 0);
		if (ssv != NULL){
            s[x] = (char *)malloc( SvCUR(*ssv) + 1 );
            // Test commented out; fails with some perl versions, for no
            // good reason
			//if (SvPOK(*ssv))
				strcpy(s[x], SvPV(*ssv, PL_na));
			//else
			//	warn("unpack_args: array elem %d was not a string.", x);
		}
	}
	s[x] = (char*)NULL; /* sentinel */
	return s;
}

/*
 * Convert a C char** to a Perl AV*, freeing the char** and the strings
 * stored in it.  The function name is dictated by the mapping in the
 * default typemap i.e.
 * (char** -> T_PACKEDARRAY -> XS_pack_charPtrPtr
 */
void XS_pack_charPtrPtr(SV* st, char **s, int n) {
	AV *av = newAV();
	SV *sv;
	char **c;
    if (!s)
        return;
	for(c = s; *c; c++){
		sv = newSVpv(*c, 0);
		av_push(av, sv);
        free(*c);
	}
	sv = newSVrv(st, NULL);	  /* upgrade stack SV to an RV */
	SvREFCNT_dec(sv);         /* discard */
	SvRV(st) = (SV*)av;       /* make stack RV point at our AV */
    free(s);
}

MODULE = NativeTWikiSearch     PACKAGE = NativeTWikiSearch

char**
cgrep(argv)
	char ** argv
    PREINIT:
        int count_charPtrPtr;
