/*
 * Copyright (C) 2004 Wind River Systems..
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details, published at 
 * http://www.gnu.org/copyleft/gpl.html
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>

/* If PROT_PRINT is defined, we are compiling for tests of the
 * protections database management. Don't compile the stuff related
 * to mod_dav */
#ifndef PROT_PRINT
#include "httpd.h"
#include "http_config.h"
#include "http_core.h"
#include "http_log.h"
#include "http_main.h"
#include "http_protocol.h"
#include "http_request.h"
#include "util_script.h"

#include "mod_dav.h"

#include "dav_twiki.h"
#include "dav_fs_repos.h"

#include "dav_opaquelock.h"
#endif

#ifdef SDBM
#include "sdbm/sdbm.h"
#define DBM_OPEN(_f,_m,_fl); sdbm_openN((_f), (_m), (_p));
#define DBM_CLOSE(_db) sdbm_close(_db)
#define DBM_FETCH(_k,_d) sdbm_fetch((_k),(_d))
#define DBM_DATUM datum
#define DBM_FIRSTKEY(db) sdbm_firstkey(db)
#define DBM_NEXTKEY(db,d) sdbm_nextkey(db)
#define DBM_FREE(x)
#else
#include "../tdb/tdb.h"
#define DBM TDB_CONTEXT
#define DBM_OPEN(_f,_m,_p) tdb_open((_f),0,TDB_DEFAULT,(_m),(_p))
#define DBM_CLOSE(_db) tdb_close(_db)
#define DBM_FETCH(_k,_d) tdb_fetch((_k),(_d))
#define DBM_FIRSTKEY(db) tdb_firstkey(db)
#define DBM_NEXTKEY(db,d) tdb_nextkey(db,d)
#define DBM_DATUM TDB_DATA
#define DBM_FREE(x) { if((x).dptr) free((x).dptr); }
#define DBM_ERROR(_db) tdb_error(_d)
#endif

/*
 * C interface to TWiki protections database.
 */
static char dbfile[512];

static int barred(char* path, char mode, const char* user,
				  DBM* db, int m);
static DBM_DATUM getKey(const char* path, const char* ad,
						  DBM* db);
static int isInList(DBM_DATUM list, const char* user,
					DBM* db, int depth);
static int isInGroup(const char* group, const char*user,
					 DBM* db, int depth);
static int isAccessible(DBM* db, const char* web, const char* topic,
						char mode, const char* user, int m);
static int checkAccessibility(const char* web,
  const char* topic,
  const char* file,
  char mode,
  const char* user,
							  int monitor);

static char* dump(DBM_DATUM d) {
  static char dumpdata[16384];
  strncpy(dumpdata, d.dptr, d.dsize);
  dumpdata[d.dsize] = 0;
  return dumpdata;
}

/**
 * Define where the lock database is. The dbname passed is the name of
 * the DAV lock database, so to get the name of the TWiki database we replace
 * the file name component with "TWiki".
 */
int dav_twiki_setDBpath(const char* dbname) {
  const char* p = dbname + strlen(dbname);;
  while (p > dbname && *p != '/' && *p != '\\')
	p--;
  strcpy(dbfile, dbname);
  dbfile[p - dbname] = '\0';
  strcat(dbfile, "/TWiki");
  return 1;
}

#ifndef PROT_PRINT
/**
 * Main interface to permissions database. KISS.
 * Returns an HTTP error code or OK
 */
int dav_twiki_accessible(request_rec *r, const dav_resource* dr,
                         int tgt) {
  twiki_resources* tr;
  char mode;
  const char* pw;

  /* determine our TWiki access mode */
  if (r->method_number == M_GET ||
	  (r->method_number == M_COPY && !tgt) ||
	  r->method_number == M_PROPFIND)
	mode = 'V';/*IEW*/
  else if (r->method_number == M_PUT ||
		   r->method_number == M_POST ||
		   r->method_number == M_LOCK ||
		   r->method_number == M_UNLOCK ||
		   r->method_number == M_PROPPATCH ||
		   (r->method_number == M_COPY && tgt) ||
		   (r->method_number == M_MOVE && tgt))
	mode = 'C';/*HANGE*/
  else if (r->method_number == M_DELETE ||
		   (r->method_number == M_MOVE && !tgt))
	mode = 'R';/*ENAME*/
  else
	return OK;
  
  tr = dr->twiki;

  /* if this is a twiki resource, check permissions */
  if (tr) {
	if (dr->collection && mode != 'V')
      /* no change access to collection */
      return HTTP_FORBIDDEN;

	/**
     * If connection->user has not been set by the authentication method,
     * then try and fill it in using basic_auth. A user identity must be
     * available for access to DAV directories. */
	if (!r->connection->user) {
	  int code = ap_get_basic_auth_pw((request_rec*)r, &pw);
      if (code != OK) {
        /* SMELL: should make this configurable */
        tr->user = ap_pstrdup(r->pool, "guest");
      } else
        tr->user = ap_pstrdup(r->pool, r->connection->user);
	} else
      tr->user = ap_pstrdup(r->pool, r->connection->user);

	if (!checkAccessibility(tr->web, tr->topic, tr->file, mode, tr->user,
							dav_get_monitor(r)))
      return HTTP_UNAUTHORIZED;
  }

  return OK;
}

#endif

/* Ignore ,v and .lock files in twiki resources at all times */
int dav_twiki_ignore_file(const char* file) {
  if (!file || strlen(file) < 2)
	return 0;

  if (strcmp(file + strlen(file) - 2, ",v") == 0)
	return 1;

  if (strlen(file) < 5)
	return 0;

  if (strcmp(file + strlen(file) - 5, ".lock") == 0)
	return 1;

  return 0;
}

/* Return 1 if accessible */
static int checkAccessibility(const char* web,
  const char* topic,
  const char* file,
  char mode,
  const char* user,
  int monitor) {

  DBM* db = NULL;
  int ret;

  /* Do collection checks before opening protections DB */
  if (mode != 'V') {
	/* disallow change ops on directories */
	if (file == NULL || topic == NULL || web == NULL) {
	  return 0;
	}
  }

  /* ,v and .lock file access is always denied, in all modes */
  if (dav_twiki_ignore_file(file)) {
	return 0;
  }

  if ((monitor & 4) != 0)
	fprintf(stderr, "Check access %s/%s/%s:%c for %s\n",
			web, topic, file, mode, user);

  db = DBM_OPEN(dbfile, O_RDONLY, 0);

  if (db == NULL) {
	/* No DB, access is permitted */
	if (monitor)
	  fprintf(stderr, "Can't open %s: %s\n",
			  dbfile, strerror(errno));
	return 1;
  }

  if ((monitor & 8) != 0) {
    /* Dump the whole database */
	DBM_DATUM d1, d2;
	fprintf(stderr, "<DB %s>\n", dbfile);
	d1 = DBM_FIRSTKEY(db);
	while(d1.dptr && d1.dsize) {
	  fprintf(stderr,"\t%s => ", dump(d1));
	  d2 = DBM_FETCH(db, d1);
	  fprintf(stderr,"%s\n", dump(d2));
	  DBM_FREE(d2);
	  d2 = DBM_NEXTKEY(db,d1);
	  DBM_FREE(d1);
	  d1 = d2;
	}
	fprintf(stderr, "</DB>\n");
  }

  ret = isAccessible(db, web, topic, mode, user, monitor);
  DBM_CLOSE(db);

  return ret;
}

static int isAccessible(DBM* db, const char* web, const char* topic,
						char mode, const char* user, int monitor) {
  static char path[16384];

  if ((monitor & 4) != 0)
    fprintf(stderr, "Test access to / for user %s\n", user);

  strcpy(path, "P:/");
  if (barred(path, mode, user, db, monitor)) {
	return 0;
  }

  if (web) {
	strcat(path, web);
	strcat(path, "/");

	if ((monitor & 4) != 0)
	  fprintf(stderr, "Test access to %s:%c for user %s\n",path,mode,user);

	if (barred(path, mode, user, db, monitor)) {
	  return 0;
	}

	if (topic) {
	  strcat(path, topic);

	  if ((monitor & 4) != 0)
		fprintf(stderr, "Test access to %s:%c for user %s\n",path,mode,user);

	  if (barred(path, mode, user, db, monitor)) {
		return 0;
	  }
	}
  }

  if ((monitor & 4) != 0)
	fprintf(stderr, "%s:%c for %s is accessible\n",path,mode,user);

  return 1;
}

static int barred(char* path, char mode, const char* user,
		   DBM* db, int monitor) {
  DBM_DATUM list;
  int l = strlen(path);
  int denied = 0;

  strcat(path, ":");
  strcat(path, " :");
  path[l + 1] = mode;

  /* Paranoia; deny before allow */
  if (user) {
	list = getKey(path, "D", db);
	if (list.dptr) {
	  /* user must not be in deny list */
	  denied = (isInList(list, user, db, 0));
	  DBM_FREE(list);
	}
  }

  if (denied) {
    if ((monitor & 4) != 0)
	  fprintf(stderr,"\tdenied by rule %sD => %s\n", path, dump(list));
  } else {
	list = getKey(path, "A", db);
	if (list.dptr) {
	  /* user must be in good list */
	  denied = (user == NULL || !isInList(list, user, db, 0));
	  DBM_FREE(list);
	}
    if (denied && (monitor & 4) != 0)
	  fprintf(stderr,"\tdenied by rule %sA => %s\n", path, dump(list));
  }


  path[l] = '\0';

  return denied;
}

static DBM_DATUM getKey(const char* path, const char* ad, DBM* db) {
  static char keyn[16384];
  DBM_DATUM key;

  strcpy(keyn, path);
  strcat(keyn, ad);

  key.dptr = keyn;
  key.dsize = strlen(keyn);
  return DBM_FETCH(db, key);
}

/**
 * Determine if the user is in the given group. Note that there is
 * a risk the the group is cyclically defined, so we end up opening
 * a group we are already in. To avoid that risk we maintain a count
 * of the number of groups opened, and will give up if it reaches 100
 */
static int isInGroup(const char* group, const char*user, DBM* db, int depth) {
  DBM_DATUM expanded;
  int ret;

  if (depth > 99) {
	fprintf(stderr, "Infinite cycle in TWiki group %s\n", group);
	return 0;
  }

  expanded = getKey("G:", group, db);
  ret = 0;
  if (expanded.dptr) {
	ret = isInList(expanded, user, db, depth);
	DBM_FREE(expanded);
  }
  return ret;
}

static int isInList(DBM_DATUM list, const char* user, DBM* db, int depth) {
  const char* start = list.dptr;
  const char* stop = list.dptr + list.dsize;
  const char* end;
  char* group;

  while (start != stop) {
	start++; /* skip the | */
	end = start;
	while (end != stop && *end != '|')
	  end++;
	if (!*end)
	  return 0;
	if (end != start && strncmp(start, user, end - start) == 0) {
	  return 1;
	}
	if (strncmp(start + (end - start - 5), "Group", 5) == 0) {
	  group = (char*)calloc(end - start + 1, 1);
	  strncpy(group, start, end - start);
	  group[end - start] = '\0';
	  if (isInGroup(group, user, db, depth + 1)) {
		free(group);
		return 1;
	  }
	  free(group);
	}
	start = end;
  }
  return 0;
}

#ifndef PROT_PRINT
const char* dav_twiki_tostring(const dav_resource* r) {
  pool* p = dav_fs_pool(r);
  const char* exists = r->exists ? "exists" : "does not exist";
  const char* collection = r->collection ? "collection" : "file";
  const char* versioned = r->versioned ? "versioned" : "unversioned";
  const char* web = r->twiki? r->twiki->web : "";
  const char* topic = r->twiki? r->twiki->topic : "";
  const char* type = NULL;
	
  switch (r->type) {
  case DAV_RESOURCE_TYPE_REGULAR: type = "regular"; break;
  case DAV_RESOURCE_TYPE_REVISION: type = "revision"; break;
  case DAV_RESOURCE_TYPE_HISTORY: type = "history"; break;
  case DAV_RESOURCE_TYPE_WORKSPACE: type = "workspace"; break;
  case DAV_RESOURCE_TYPE_ACTIVITY: type = "activity"; break;
  case DAV_RESOURCE_TYPE_CONFIGURATION: type = "configuration"; break;
  }
	
  return ap_psprintf(p,
					 "%s: %s %s %s, %s, base %d work %d (twiki %s/%s)",
					 r->uri,
					 type,
					 versioned,
					 collection,
					 exists,
					 r->baselined,
					 r->working,
					 web,
					 topic);
}

static char* escaped(const char* s, char* tmp) {
  char* d = tmp;
  while (*s != '\0') {
	if (('a' <= *s && *s <= 'z') ||
		('A' <= *s && *s <= 'Z') ||
		('0' <= *s && *s <= '9') ||
		*s == '.') {
	  *d++ = *s;
	} else {
	  *d++ = '%';
	  sprintf(d, "%.2x", *s);
	  d += 2;
	}
	s++;
  }
  *d = '\0';
  return tmp;
}

static char* compile_resource(pool* poo, twiki_resources* tr) {
  char tmpw[512];
  char tmpt[512];
  char tmpa[512];

  const char* basename = NULL;
  if (tr->file) {
	basename = tr->file + strlen(tr->file);
	while (basename > tr->file && *basename != '\\' && *basename != '/')
	  basename--;
	if (basename > tr->file)
	  basename++;
  }
  if (tr->type == TWIKI_DATA)
	return ap_psprintf(poo,
					   "%s/%s",
					   escaped(tr->web, tmpw),
					   basename ? escaped(basename, tmpa) : "");
  else
	return ap_psprintf(poo,
					   "%s/%s/%s",
					   escaped(tr->web, tmpw),
					   escaped(tr->topic, tmpt),
					   basename ? escaped(basename, tmpa) : "");
}

const char* dav_twiki_make_tmp_filename(pool* p) {
  char* s = ap_psprintf(p, "%s/davXXXXXX", P_tmpdir);
  mkstemp(s);
  return s;
}

static dav_error* invoke_command(const char* action,
								 const dav_resource* r,
								 const char* path) {
  pool* p = dav_fs_pool(r);
  const char* cmd;
  twiki_resources* tr = r->twiki;
  const char* response_file = dav_twiki_make_tmp_filename(p);

  cmd = ap_psprintf(p,
					"%s %s %s %s %s %s",
					tr->script,
					response_file,
					tr->user ? tr->user : "guest",
					action,
					compile_resource(p, r->twiki),
					path);

  if (system(cmd)) {
	FILE* f = fopen(response_file, "r");
	char mess[512];
	int nb = 0;
	if (f) {
	  nb = fread(mess, 1, 511, f);
	  fclose(f);
	  remove(response_file);
	  if (nb < 0)
		nb = 0;
	}
	mess[nb] = '\0';
	if (r->monitor & 1)
	  fprintf(stderr, "%s evoked response %s\n", cmd, mess);
	return dav_new_error(p, HTTP_FORBIDDEN, 0, ap_psprintf(p, "%s", mess));
  }

  return NULL;
}

dav_error* dav_twiki_delete(const dav_resource* r) {
  return invoke_command("delete", r, "");
}

dav_error* dav_twiki_commit(const dav_resource* r, const char* path) {
  char tmp[512];
  return invoke_command("attach", r, escaped(path, tmp));
}

const char * dav_twiki_detach_metadata(const dav_resource *resource)
{
  const char* tmp = dav_twiki_make_tmp_filename(dav_fs_pool(resource));
  dav_error* e = invoke_command("unmeta", resource, tmp);

  if (e) {
	remove(tmp);
	return NULL;
  }
  return tmp;
}

dav_error* dav_twiki_reattach_metadata(const char *alt,
									   const dav_resource *resource)
{
  return invoke_command("remeta", resource, alt);
}

dav_error* dav_twiki_move(const dav_resource* s, const dav_resource* d) {
  return invoke_command("move", s, compile_resource(dav_fs_pool(s), d->twiki));
}

#endif
