cvs update

 . ~/twikiplugindev/settwikivars.sh

cd lib/TWiki/Plugins/TWikiReleaseTrackerPlugin

for i in $TWIKI_HOMES
do
   echo "Installing to $i"
   export TWIKI_HOME=$HOME/$i
   perl build.pl install
   echo
done

