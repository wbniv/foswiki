/*
** Copyright (C) 2004 Wind River Systems Inc.
**
** Interface to versioning operations
*/
#include "httpd.h"
#include "http_log.h"

#include "mod_dav.h"
#include "dav_fs_repos.h"
#include "dav_twiki.h"

extern const dav_hooks_vsn dav_hooks_vsn_fs;

static void monitor(const char* mess, dav_resource* resource) {
  if (resource->monitor < 2)
	return;

  fprintf(stderr, "DAV_FS_VSN: %s %s\n", mess, dav_twiki_tostring(resource));
}

/*
 * Return supported versioning level for the Versioning header
 */
static const char * dav_fs_get_vsn_header(void) {
    return "version-control,checkout,checkin,uncheckout";
}

/* Create a new (empty) resource. If successful,
 * the resource object state is updated appropriately.
 */
static dav_error * dav_fs_mkresource(dav_resource *resource)
{
    const char *dirpath;
	pool* p;

	monitor("MKRESOURCE ", resource);
    dav_fs_dir_file_name(resource, &dirpath, NULL);
    p = dav_fs_pool(resource);
    return dav_new_error(p,
			 HTTP_BAD_REQUEST,
			 0,
			 ap_psprintf(p, "MkResource %s", dirpath));
    /* TODO: need to update resource object state */
}

/* Checkout a resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_checkout(dav_resource *resource) {

  monitor("CHECKOUT ", resource);
  /* working is supposed to be the revision number of the working
   * revision, but I'm cheating here and simply using it as a
   * semaphore to ensure the rest of mod_dav understands that this
   * file is checked out. */
  resource->working = 1;
  return NULL;
}

/* Uncheckout a resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_uncheckout(dav_resource *resource)
{
  if (resource->twiki) {
	monitor("UNCHECKOUT ", resource);
    resource->working = 0;
  }
  return NULL;
}

/* Checkin a working resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_checkin(dav_resource *resource)
{
  dav_error* e;

  if (resource->twiki) {
	monitor("CHECKIN ", resource);
	e = dav_twiki_commit(resource, resource->twiki->file);
	if (e)
	  return e;

	/* release the resource */
	resource->working = 0;
  }

  return NULL;
}

/* Determine whether a non-versioned (or non-existent) resource
 * is versionable. Returns != 0 if resource can be versioned.
 */
static int dav_fs_versionable(const dav_resource *resource)
{
  return (resource->twiki != NULL);
}

/* Determine whether auto-versioning is enabled for a resource
 * (which may not exist, or may not be versioned).
 * Returns != 0 if auto-versioning is enabled.
 */
static int dav_fs_auto_version_enabled(const dav_resource *resource)
{
    /* TWiki leaf resources are auto-versioned */
    return (resource->twiki != NULL &&
			resource->twiki->file != NULL);
}

/* Don't actually use all these hooks, just get_vsn_header, checkout,
 * checkin and uncheckout, but implement them all because don't fully
 * understand the protocol (and it's unfinished in this version of
 * mod_dav anyway) */
const dav_hooks_vsn dav_hooks_vsn_fs = {
    &dav_fs_get_vsn_header,
    &dav_fs_mkresource,
    &dav_fs_checkout,
    &dav_fs_uncheckout,
    &dav_fs_checkin,
    &dav_fs_versionable,
    &dav_fs_auto_version_enabled
};
