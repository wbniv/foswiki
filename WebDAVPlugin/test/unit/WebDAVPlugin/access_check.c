#define PROT_PRINT 1
#include "../../../lib/twiki_dav/dav_twiki.c"
int main(int argc, const char** argv) {
  int ret;
  const char* web = argv[1];
  const char* topic = argv[2];
  const char* file = argv[3];
  const char* mode = argv[4];
  const char* user = argv[5];
  const char* db = argv[6];
  const char* mon = argv[7];
  int monitor = atoi(mon);
  if (strcmp(web,"-") == 0)
	web = NULL;
  if (strcmp(topic,"-") == 0)
	topic = NULL;
  if (strcmp(file,"-") == 0)
	file = NULL;
  if (strcmp(user,"-") == 0)
	user = NULL;
  dav_twiki_setDBpath(db);
  if (checkAccessibility(web, topic, file, mode[0], user, monitor))
	printf("permitted\n");
  else
	printf("denied\n");

  return 0;
}
