#include "includes.h"
#include <gdbm.h>

/* Turn off if error returns from TDB are sane (before v1.0.2) */
#if 1
#define TDB_ERROR(tdb, code) ((tdb)->ecode == code)
#else
#define TDB_ERROR(tdb, code) 1
#endif
/* a test program for tdb - the trivial database */

static TDB_DATA *randdata, *randkeys;

#define DELETE_PROB 7
#define STORE_PROB 5

static TDB_CONTEXT *db;
static GDBM_FILE gdbm;

struct timeval tp1,tp2;

static void start_timer()
{
	gettimeofday(&tp1,NULL);
}

static double end_timer()
{
	gettimeofday(&tp2,NULL);
	return((tp2.tv_sec - tp1.tv_sec) + 
	       (tp2.tv_usec - tp1.tv_usec)*1.0e-6);
}

static void fatal(TDB_CONTEXT *tdb, const char *why)
{
	perror(why);
	if (tdb) fprintf(stderr, "TDB: (%u)\n", tdb->ecode);
	exit(1);
}

static char *randbuf(int len)
{
	char *buf;
	int i;
	buf = (char *)malloc(len+1);

	for (i=0;i<len;i++) {
		buf[i] = 'a' + (rand() % 26);
	}
	buf[i] = 0;
	return buf;
}

static void addrec_db(int i)
{
	TDB_DATA key, data;

	key.dptr = randkeys[i].dptr;
	key.dsize = randkeys[i].dsize+1;

	data.dptr = randdata[i].dptr;
	data.dsize = randdata[i].dsize+1;

	if (rand() % DELETE_PROB == 0) {
		if (tdb_delete(db, key) == -1
		    && !TDB_ERROR(db, TDB_ERR_NOEXIST))
			fatal(db, "tdb_delete failed");
	} else if (rand() % STORE_PROB == 0) {
		if (tdb_store(db, key, data, TDB_REPLACE) != 0) {
			fatal(db, "tdb_store failed");
		}
	} else {
		data = tdb_fetch(db, key);
		if (data.dptr) free(data.dptr);
		else {
			if (db->ecode && !TDB_ERROR(db,TDB_ERR_NOEXIST))
				fatal(db, "tdb_fetch failed");
		}
	}
}

struct db_size {
	const char *name;
	int size;
} db_sizes[]
= { { "default", 0 },
    { "307", 307 },
    { "512", 512 },
    { "1024", 1024 },
    { "4096", 4096 },
    { "16384", 16384 },
    { "65536", 65536 } };

unsigned int num_loops[]  /* 10,000 each */
= { 1, 5, 25 };

struct tdb_flag {
	const char *name;
	int flags;
} tdb_flags[]
= { { "normal", TDB_CLEAR_IF_FIRST },
#ifdef TDB_CONVERT
    { "byte-reversed", TDB_CLEAR_IF_FIRST|TDB_CONVERT }
#endif
};

int main(int argc, char *argv[])
{
	int i, j, seed=0;
	int k;

	/* Precook random buffers */
	randdata = malloc(10000 * sizeof(randdata[0]));
	randkeys = malloc(10000 * sizeof(randkeys[0]));

	srand(seed);
	for (i=0;i<10000;i++) {
		randkeys[i].dsize = 1 + (rand() % 4);
		randdata[i].dsize = 1 + (rand() % 100);
		randkeys[i].dptr = randbuf(randkeys[i].dsize);
		randdata[i].dptr = randbuf(randdata[i].dsize);
	}

	for (k = 0; k < sizeof(tdb_flags)/sizeof(struct tdb_flag); k++) {
		printf("Operations per second for %s database:\n",
		       tdb_flags[k]);

		printf("Hashsize:   ");
		for (i = 0; i < sizeof(db_sizes)/sizeof(struct db_size); i++)
			printf("%-8s ", db_sizes[i].name);
		printf("\n");
		
		for (i = 0; i < sizeof(num_loops)/sizeof(int); i++) {
			printf("%7u:    ", num_loops[i]*10000);
			for (j = 0; j < sizeof(db_sizes)/sizeof(struct db_size); j++) {
				unsigned int l, l2;
				db = tdb_open("test.tdb", db_sizes[j].size,
					      tdb_flags[k].flags,
					      O_RDWR | O_CREAT | O_TRUNC, 0600);
				srand(seed);
				start_timer();
				for (l2=0; l2 < num_loops[i]; l2++)
					for (l=0;l<10000;l++) addrec_db(l);
				printf("%-7u  ", (int)(l*l2/end_timer()));
				tdb_close(db);
			}
			printf("\n");
		}
		printf("\n");
	}
	return 0;
}
