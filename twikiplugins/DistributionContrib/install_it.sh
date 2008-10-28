cvs update

 . ~/twikiplugindev/settwikivars.sh

cd lib/TWiki/Contrib/DistributionContrib

for i in $TWIKI_HOMES
do
   echo "Installing to $i"
   export TWIKI_HOME=$HOME/$i
   perl build.pl install
   echo
done

