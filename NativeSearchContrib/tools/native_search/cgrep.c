/* Copyright (C) 2007 WikiRing http://wikiring.com All Rights Reserved
 * Author: Crawford Currie
 * Fast grep function designed for use from Perl. Does not suffer from
 * limitations of `grep` viz. cost of spawning a subprocess, and
 * limits on command-line length.
 */
#include <pcre.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define DATABUFSIZE  4192
#define ERRBUFSIZE   256
#define MATCHBUFSIZE 1

int _getline (char **lineptr, size_t *n, FILE *stream);

#ifndef warn
#define warn printf
#endif

/* Copy the static match buffer into heap memory, resizing as required */
char** _backup(int mc, char** m, char** r) {
    int curlen = 0;
    char** newR = NULL;
    if (!mc) {
        return r;
    }
    if (r) {
        while (r[curlen]) {
            curlen++;
        }
        newR = (char**)realloc(r, sizeof(char*) * (curlen + mc + 1));
    }

    if (!newR) {
        newR = (char**)malloc(sizeof(char*) * (mc + 1));
    }

    memcpy(newR + curlen, m, sizeof(char*) * mc);
    newR[curlen + mc] = NULL;

    return newR; 
}

/* Release memory used in the XS interface */
void cleanup(char** argv) {
    char** ptr = argv;

    while (*ptr) {
        free(*ptr);
        ptr++;
    }
    free(argv);
}



/* Do a grep. Arguments are provided in argv, options first, then the
 * pattern, then the file names. -i (case insensitive) and -l (report
 * matching file names only) are the only options supported. */
char** cgrep(char** argv) {
    char** argptr = argv;
    /* Check for UTF8 support using pcre_config */
    int erk;
    int reflags = PCRE_NO_AUTO_CAPTURE;
    int justFiles = 0;
    FILE* f;
    pcre* pattern;
    pcre_extra* study;
    int linebufsize = DATABUFSIZE;
    char* linebuf;
    char* matchCache[MATCHBUFSIZE];
    int matchCacheSize = 0;
    char** result = NULL;
    int resultSize;
    char* fname;
    const char* err;
    int errPos;

    if (pcre_config(PCRE_CONFIG_UTF8, &erk) && erk) {
        reflags |= PCRE_UTF8 | PCRE_NO_UTF8_CHECK;
    }
    while (*argptr) {
        char* arg = *(argptr++);
        if (strcmp(arg, "-i") == 0) {
            reflags |= PCRE_CASELESS;
        } else if (strcmp(arg, "-l") == 0) {
            justFiles = 1;
        } else {
            /* Convert \< and \> to \b in the pattern. GNU grep supports
               them, but pcre doesn't :-( */
            if (*arg) {
                for (linebuf = arg + 1; *linebuf; linebuf++) {
                    if (*linebuf == '\\' && *(linebuf-1) != '\\' &&
                        *(linebuf+1) == '<' || *(linebuf+1) == '>')
                        *(linebuf+1) = 'b';
                }
            }
            if (!(pattern = pcre_compile(arg, reflags, &err, &errPos, NULL))) {
                warn(err);
            }
            if (!pattern) {
                cleanup(argv);
                return NULL;
            }
            break;
        }
    }

    /* Study the pattern to accelerate matching */
    study = pcre_study(pattern, 0, &err);
    if (err) {
        warn(err);
        cleanup(argv);
        return NULL;
    }

    linebuf = malloc(linebufsize);
    while (*argptr) {
        fname = *(argptr++);
        f = fopen(fname, "r");
        if (f) {
            int ern;
            int mi;
            int size;
            char ch = 0;
            int ovec[30];
            int matchResult;
            int chc;
            while ((chc = _getline(&linebuf, &linebufsize, f)) > 0) {
                matchResult = pcre_exec(pattern, study, linebuf,
                                        chc, 0, 0, ovec, 30);
                if (matchResult >= 0) {
                    /* Successful match */
                    if (matchCacheSize == MATCHBUFSIZE) {
                        /* Back up the cache if it's full */
                        result = _backup(matchCacheSize, matchCache, result);
                        matchCacheSize = 0;
                    }
                    mi = matchCacheSize++;
                    size = strlen(fname);
                    if (linebuf[strlen(linebuf)-1] == '\n') {
                        linebuf[strlen(linebuf)-1] = '\0';
                    }
                    if (!justFiles) {
                        size += 1 + strlen(linebuf);
                    }
                    matchCache[mi] = (char*)malloc(size + 1);
                    strcpy(matchCache[mi], fname);
                    if (!justFiles) {
                        strcat(matchCache[mi], ":");
                        strcat(matchCache[mi], linebuf);
                        /* go to next matching line in this file */
                    } else {
                        break; /* go to next file */
                    }
                }
            }        
            fclose(f);
        } else {
            warn("Open failed %d", errno);
        }
    }
    free(linebuf);
    result = _backup(matchCacheSize, matchCache, result);
    cleanup(argv);
    return result;
}

/* Taken from getline.c -- Replacement for GNU C library function getline

Copyright (C) 1993 Free Software Foundation, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.  */

/* Written by Jan Brittenson, bson@gnu.ai.mit.edu.  */

/* Always add at least this many bytes when extending the buffer.  */
#define MIN_CHUNK 64

/* Read up to (and including) a TERMINATOR from STREAM into *LINEPTR
   + OFFSET (and null-terminate it).  If LIMIT is non-negative, then
   read no more than LIMIT chars.

   *LINEPTR is a pointer returned from malloc (or NULL), pointing to
   *N characters of space.  It is realloc'd as necessary.  

   Return the number of characters read (not including the null
   terminator), or -1 on error or EOF.  On a -1 return, the caller
   should check feof(), if not then errno has been set to indicate the
   error.  */

#define GETLINE_NO_LIMIT -1

int _getstr(char **lineptr,
           size_t *n,
           FILE *stream,
           int terminator,
           int offset,
           int limit) {
    int nchars_avail;		/* Allocated but unused chars in *LINEPTR.  */
    char *read_pos;		/* Where we're reading into *LINEPTR. */
    int ret;

    if (!lineptr || !n || !stream) {
        errno = EINVAL;
        return -1;
    }

    if (!*lineptr) {
        *n = MIN_CHUNK;
        *lineptr = malloc (*n);
        if (!*lineptr) {
            errno = ENOMEM;
            return -1;
        }
        *lineptr[0] = '\0';
    }

    nchars_avail = *n - offset;
    read_pos = *lineptr + offset;

    for (;;) {
        int save_errno;
        register int c;

        if (limit == 0)
            break;
        else {
            c = getc (stream);

            /* If limit is negative, then we shouldn't pay attention to
               it, so decrement only if positive. */
            if (limit > 0)
                limit--;
        }

        save_errno = errno;

        /* We always want at least one char left in the buffer, since we
           always (unless we get an error while reading the first char)
           NUL-terminate the line buffer.  */

        /*assert((*lineptr + *n) == (read_pos + nchars_avail));*/
        if (nchars_avail < 2) {
            if (*n > MIN_CHUNK)
                *n *= 2;
            else
                *n += MIN_CHUNK;

            nchars_avail = *n + *lineptr - read_pos;
            *lineptr = realloc (*lineptr, *n);
            if (!*lineptr) {
                errno = ENOMEM;
                return -1;
            }
            read_pos = *n - nchars_avail + *lineptr;
            /*assert((*lineptr + *n) == (read_pos + nchars_avail));*/
        }

        if (ferror (stream)) {
            /* Might like to return partial line, but there is no
               place for us to store errno.  And we don't want to just
               lose errno.  */
            errno = save_errno;
            return -1;
        }

        if (c == EOF) {
            /* Return partial line, if any.  */
            if (read_pos == *lineptr)
                return -1;
            else
                break;
        }

        *read_pos++ = c;
        nchars_avail--;

        if (c == terminator)
            /* Return the line.  */
            break;
    }

    /* Done - NUL terminate and return the number of chars read.  */
    *read_pos = '\0';

    ret = read_pos - (*lineptr + offset);
    return ret;
}

int _getline (char **lineptr, size_t *n, FILE *stream) {
    return _getstr (lineptr, n, stream, '\n', 0, GETLINE_NO_LIMIT);
}
