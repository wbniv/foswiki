#include "includes.h"

int tdb_print(TDB_CONTEXT *tdb, TDB_DATA key, TDB_DATA data, void *state)
{
	printf("Traverse: %s = %s\n", key.dptr, data.dptr);
	return 0;
}

int main(int argc, char *argv[])
{
	TDB_DATA k,d;
	TDB_CONTEXT *db;
	int i;

	db = tdb_open("test.tdb", 307, TDB_CLEAR_IF_FIRST, 
		      O_RDWR | O_CREAT | O_TRUNC, 0600);

	k.dptr = "hello";
	k.dsize = sizeof("hello");
	d.dptr = "HELLO";
	d.dsize = sizeof("HELLO");
	tdb_store(db, k, d, TDB_INSERT);

	k.dptr = "world";
	k.dsize = sizeof("world");
	d.dptr = "WORLD";
	d.dsize = sizeof("WORLD");
	tdb_store(db, k, d, TDB_INSERT);

	if (tdb_traverse(db, tdb_print, NULL) != 2) {
		fprintf(stderr, "Traverse didn't complete!\n");
		exit(1);
	}

	/* Leaky, but who cares. */
	for (i = 0, k = tdb_firstkey(db); k.dptr; k = tdb_nextkey(db, k), i++){
		d = tdb_fetch(db, k);
		printf("Iterate: %s = %s\n", k.dptr, d.dptr);
	}

	if (i != 2) {
		fprintf(stderr, "Iterate didn't complete!\n");
		exit(1);
	}
	return 0;
}
