
PLATFORM ?= darwin

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

all: FirefoxExtensionAddOn.xpi

twiki-$(PLATFORM).tar.bz2 :
	tar -c $(TAR_EXCLUDE) --no-recursion -f twiki-$(PLATFORM).tar --directory platform/$(PLATFORM) `cd platform/$(PLATFORM); ls` 
	tar -r $(TAR_EXCLUDE) --exclude "downloads/*/*.zip" -f twiki-$(PLATFORM).tar bin/* cpan/*.pl cpan/MIRROR/TWIKI downloads 
	bzip2 twiki-$(PLATFORM).tar

distro : twiki-cpan plugins contribs addons release twiki-$(PLATFORM).tar.bz2 

chrome/twiki.jar : cleanBackup force
	cd chrome ; rm twiki.jar ; zip -r twiki.jar content locale skin

force: 

FirefoxExtensionAddOn.xpi : cleanBackup install.rdf chrome/twiki.jar
	rm $@ ; zip $@ install.rdf chrome/twiki.jar

clean:
	FirefoxExtensionAddOn.xpi chrome/twiki.jar

cleanBackup:
	find . \( -name '*~' -o -name '*.bak' -o -name '*.old' \) -exec rm '{}' \;

release :
	wget -nc --http-user=TWikiGuest --http-passwd=guest -O downloads/releases/TWiki20040901.tar.gz http://twiki.org/release/TWiki20040901.tar.gz

print :
	@echo PLATFORM = $(PLATFORM)
