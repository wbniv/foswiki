#!/bin/sh

if [ -e /tmp/build_deb ]; then
	echo '/tmp/build_deb already exists, please move aside'
	exit -1;
fi
if [ ! -e TWiki-4.1.2.tgz ]; then
	echo 'need TWiki-4.1.2.tgz file to build'
	exit -1;
fi

mkdir /tmp/build_deb
cp TWiki-4.1.2.tgz /tmp/build_deb/twiki_4.1.2.orig.tar.gz

mkdir /tmp/build_deb/twiki-4.1.2 

cp -r debian /tmp/build_deb/twiki-4.1.2
cd /tmp/build_deb/twiki-4.1.2
find . -name .svn -exec rm -rf '{}' \;

tar zxvf /tmp/build_deb/twiki_4.1.2.orig.tar.gz

#patch it
#fakeroot debian/rules patch

#debuild
#see http://www.debian.org/doc/maint-guide/ch-build.en.html
dpkg-buildpackage -rfakeroot

#TODO
#interdiff -z twiki_4.1.2-{8,9}.diff.gz
#upload this too

#push into the DistributedINFORMATION.com apt repository
#cd repos
#./updateRepos.sh
