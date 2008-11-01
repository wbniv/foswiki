/* C version of pccr, Algorithm revision: 2
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/sendfile.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>
extern char **environ;
extern char *stpcpy(char *dest, char *src);

/* constants defined on install */
char *bin = "XXXbinXXX";
char *view = "XXXviewXXX";
char *cache = "XXXcacheXXX";
char *logs = "XXXlogsXXX";
char *webhome = "XXXwebhomeXXX";

/* forward decls */
char *strcatmem(char *s1, int l1, char *s2, int l2);
char *strcat2mem(char *s1, int l1, char *s2, int l2, char *s3, int l3);
char *strcat4mem(char *s1, int l1, char *s2, int l2, char *s3, int l3,
		 char *s4, int l4, char *s5, int l5);
char *rstr_remove(char *s, char *suffix);
int mmap_stdout(char *filename);
int file_exists(char *filename);
char *safegetenv(char *key);

#ifdef DEBUG
#define D(a,b) debug(a,b)
void debug(char *tag, char *s);
#else
#define D(a,b)
#endif

#ifdef NOLOG
#define L(a,b,c) 
#else
#include <time.h>
#define L(a,b,c) twlog(a, b, c)
void twlog(char *op, char *wt, char *ip);
#endif

#ifdef SENDFILE
int sendfile_stdout(char *filename);
#define mmap_stdout sendfile_stdout
#endif

int
main (int argc, char **argv) {
  char *HTTP_ACCEPT_ENCODING = safegetenv("HTTP_ACCEPT_ENCODING");
  char *QUERY_STRING = safegetenv("QUERY_STRING");
  char *PATH_INFO = safegetenv("PATH_INFO");
  char *REMOTE_ADDR = safegetenv("REMOTE_ADDR");
  char *url = PATH_INFO; int url_l = strlen(url);
  int gzip = (NULL != strstr(HTTP_ACCEPT_ENCODING, "gzip"));
  char *twiki_url;
  int cache_l = strlen(cache);
  int webhome_l = strlen(webhome);
  char *cachefile_gz, *cachefile_tx, *cachefile_nc;
  char *changer_file;

  /* do not cache if there is a query string */
  if (QUERY_STRING && QUERY_STRING[0]) {
    twiki_url = strcat4mem(bin, strlen(bin), "XXXvief_nameXXX", 
			   XXXvief_nlenXXX, url, url_l, "?", 1,
			   QUERY_STRING, strlen(QUERY_STRING));
    D("BYPASS_QS", twiki_url);
    printf("Location: %s\n\n", twiki_url);
    exit(0);
  }

#ifndef NO_CHANGERS
  /* if we are a changer, bypass cache */
  changer_file = strcat2mem(cache, cache_l, "/_changers/", 11, REMOTE_ADDR,
			    strlen(REMOTE_ADDR));
  if (file_exists(changer_file)) {
    twiki_url = strcat2mem(bin, strlen(bin), "XXXvief_nameXXX", 
			   XXXvief_nlenXXX, url, url_l);
    D("BYPASS_CHANGER_IP", REMOTE_ADDR);
    printf("Location: %s\n\n", twiki_url);
    exit(0);
  }
#endif

  /* normalize */
  if (url_l > 0 && url[url_l-1] == '/') {
    url = strcatmem(url, url_l, webhome, webhome_l);
    url_l += webhome_l;
  }
  cachefile_gz = strcat2mem(cache, cache_l, url, url_l, ".gz", 3);
  cachefile_tx = strcat2mem(cache, cache_l, url, url_l, ".tx", 3);
  cachefile_nc = strcat2mem(cache, cache_l, url, url_l, ".nc", 3);

  if (gzip && mmap_stdout(cachefile_gz)) {
    L("cached,gzip", url+1, REMOTE_ADDR);
    exit(0);
  }
  if (mmap_stdout(cachefile_tx)) {
    L("cached", url+1, REMOTE_ADDR);
    exit(0);
  }

  /* marked as never cached? */
  if (file_exists(cachefile_nc)) {
    twiki_url = strcat2mem(bin, strlen(bin), "XXXvief_nameXXX", 
			   XXXvief_nlenXXX, url, url_l);
    D("BYPASS_NC", twiki_url);
    printf("Location: %s\n\n", twiki_url);
    exit(0);
  }

  /* Then, we must let the Cache Builder pcbd do its job */
  char *args[3] = {"./pcbd", url, NULL};
  execv("./pcbd", args);

}

char *
strcatmem(char *s1, int l1, char *s2, int l2) {
  char *p, *s = malloc(l1+l2+1);
  strcpy(stpcpy(s, s1), s2);
  return s;
}

char *
strcat2mem(char *s1, int l1, char *s2, int l2, char *s3, int l3) {
  char *s = malloc(l1+l2+l3+1);
  strcpy(stpcpy(stpcpy(s, s1), s2), s3);
  return s;
}

char *
strcat4mem(char *s1, int l1, char *s2, int l2, char *s3, int l3,
	   char *s4, int l4, char *s5, int l5) {
  char *s = malloc(l1+l2+l3+l4+l5+1);
  strcpy(stpcpy(stpcpy(stpcpy(stpcpy(s, s1), s2), s3), s4), s5);
  return s;
}

/* just in case you dont have it, here it is
char *
stpcpy(char *dest, char *src) {
  char *p=src; char *q=dest;
  while (*p) *q++ = *p++;
  return q;
}
*/

/* if suffix is found at end, removes in place from s and return */
char *
rstr_remove(char *s, char *suffix) {
  int s_l = strlen(s);
  int suffix_l = strlen(suffix);
  if (s_l >= suffix_l && !strcmp(s - suffix_l, suffix)) {
    s[s_l - suffix_l] = '\0';
  }
  return s;
}

/* return 1 if file was found, else 0
 * in case of error once transfer has started it is too late, we can only exit
 */
#ifndef SENDFILE
/* using mmap. sturdy and fast */
mmap_stdout(char *filename) {
  struct stat stat_buf;
  off_t offset = 0;
  size_t len;
  void *mem;char *buf, *end; int bytes;
  int fd = open(filename, O_RDONLY);
  if (fd < 0) return 0;
  fstat(fd, &stat_buf); len = stat_buf.st_size;
  if ((mem = mmap(0, len, PROT_READ, MAP_SHARED, fd, 0)) == MAP_FAILED) {
    fprintf(stderr, "ERROR, pccr could not mmap %s\n", filename);
    close(fd);
    return 0;
  }
  buf = (char *) mem; end = buf + len;
  while (buf < end) {
    bytes = write(1, buf, end - buf);
    if (bytes <= 0) {
      fprintf(stderr, "ERROR, pccr could send only %d bytes of the %d of %s\n",
	      buf - (char *) mem, len, filename);
      break; 
    }
    buf += bytes;
  }
  munmap(mem, len);
  close(fd);
  return 1;
}

#else /* SENDFILE */
/* using sendfile. Not recommended, may cause problems and since we have
 * the overhead of being called via CGI, no significant gains.
 * included here for reference
 * see http://linuxgazette.net/issue91/tranter.html
 */
sendfile_stdout(char *filename) {
  struct stat stat_buf;
  off_t offset = 0;
  int fd = open(filename, O_RDONLY);
  if (fd < 0) return 0;
  fstat(fd, &stat_buf);
  sendfile(1, fd, &offset, stat_buf.st_size);
  close(fd);
  close(1);
  exit(0);
  return 1;
}
#endif /* SENDFILE*/

int 
file_exists(char *filename) 
{
  struct stat statbuf;
  return !stat(filename, &statbuf);
}

/* never return NULL, but static empty string */
char *
safegetenv(char *key) {
  char *value = getenv(key);
  if (value) return value;
  else return "";
}

#ifdef DEBUG
void 
debug(char *tag, char *s) {
  char *file = strcatmem(logs, strlen(logs), "/twpc-debug.txt", 15);
  FILE *fd = fopen(file, "a");
  if (fd) {
    fprintf(fd, "%s %s\n", tag, s);
    fclose(fd);
  } else {
    fprintf(stderr, "ERROR, pccr could not open twpc log file %s\n", file);
  }
}
#endif

#ifndef NOLOG
char *monthname[12] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

void 
twlog(char *op, char *wt, char *ip) {
  char logname[15];
  char *wts = (char *) malloc(strlen(wt));
  time_t epoch = time(NULL);
  struct tm *now = localtime(&epoch);
  sprintf(logname, "/log%04d%02d.txt", now->tm_year + 1900, now->tm_mon + 1);
  char *file = strcatmem(logs, strlen(logs), logname, 14);
  FILE *fd = fopen(file, "a");
  if (fd) {
    char *p, *q;
    for (p = wts, q = wt; *q; p++, q++) {
      if (*q == '/') *p = '.';
      else *p = *q;
    }
    *p = '\0';

    fprintf(fd, "| %02d %s %04d - %02d:%02d | guest | view | %s | %s | %s |\n",
	    now->tm_mday, monthname[now->tm_mon], now->tm_year + 1900,
	    now->tm_hour, now->tm_min,
	    wts, op, ip);
    fclose(fd);
  } else {
    fprintf(stderr, "ERROR, pccr could not open twiki log file %s\n", file);
  }
}
#endif
