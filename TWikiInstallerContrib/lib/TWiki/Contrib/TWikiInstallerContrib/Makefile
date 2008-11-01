
TWIKIDEV ?= ~/twiki
BRANCH ?= DEVELOP
MakeFor ?= twiki.org-`bin/svnrev.pl`

all : help

TAR_EXCLUDE = --exclude CVS --exclude .svn --exclude "*~" --exclude bak

kernel : 
	[ -e components/kernel ] || mkdir -p components/kernel
	cd $(TWIKIDEV)/$(BRANCH)/tools/; TWIKI_LIBS=$(TWIKIDEV)/$(BRANCH)/twikiplugins/BuildContrib/lib/ echo "n" | perl build.pl release; cp $(TWIKIDEV)/$(BRANCH)/TWiki.zip $(TWIKIDEV)/$(BRANCH)/twikiplugins/TWikiInstallerContrib/lib/TWiki/Contrib/TWikiInstallerContrib/components/kernel/TWikiKernel$(BRANCH)`$(TWIKIDEV)/$(BRANCH)/twikiplugins/TWikiInstallerContrib/lib/TWiki/Contrib/TWikiInstallerContrib/bin/svnrev.pl`.zip

$(MakeFor).zip : kernel 
	zip -r $(MakeFor).zip components/extension/ components/kernel/TWikiKernel$(BRANCH)`bin/svnrev.pl`.*

#	zip -r $(MakeFor).zip components/extension/ components/kernel/TWikiKernel$(BRANCH)*.zip
#	tar --file=$(MakeFor).tar --create $(TAR_EXCLUDE) components/extension/ components/kernel/TWikiKernel$(BRANCH)`bin/svnrev.pl`.*

extensions : 
	cd $(TWIKIDEV)/$(BRANCH)/tools/; TWIKI_LIBS=$(TWIKIDEV)/$(BRANCH)/twikiplugins/BuildContrib/lib/ perl build_all_extensions.pl
	[ -e components/extension ] || mkdir -p components/extension
	cp $(TWIKIDEV)/$(BRANCH)/twikiplugins/*/*.zip components/extension

TWikiFor : $(MakeFor).zip

distro : twiki-install extensions $(MakeFor).zip

twiki-install : remote-install ../TWikiInstallerContrib.pm
	cp remote-install twiki-install
	cat ../TWikiInstallerContrib.pm >>twiki-install

################################################################################

publish : publish_components

publish_distro :
	scp $(MakeFor).zip $(PUBLISH_TO)/twiki.org.zip

# NOTE: $(PUBLISH_TO)/twiki/components/extension has to already exist :(
publish_extensions :
	scp -r $(TWIKIDEV)/$(BRANCH)/twikiplugins/*/*.zip $(PUBLISH_TO)/twiki/components/extension

publish_kernels :
	scp -r components/kernel $(PUBLISH_TO)/twiki/components

publish_components : publish_distro publish_kernels publish_extensions

################################################################################

clean :
	-rm *.zip
	-rm -rf components/
	-rm install-report.html

################################################################################

print_settings :
	@echo Settings
	@echo ================================================================================
	@echo MakeFor = $(MakeFor)
	@echo TWIKIDEV = $(TWIKIDEV)
	@echo PUBLISH_TO = $(PUBLISH_TO)

print : print_settings

help : print
	@echo 
	@echo Usage
	@echo ================================================================================
	@echo make [build-options] MakeFor.zip - build and bundle extensions + kernels into .zip
	@echo 
	@echo make distro - download and bundle extensions + kernel
	@echo 
	@echo "make kernel - build TWikiKernel"
	@echo "make extensions - build extensions (all of plugins, contribs, addons)"
	@echo 
	@echo "make publish - upload distro and extensions + kernels (see below)"
	@echo "make publish_distro - upload distro"
	@echo "make publish_kernels - upload built kernels to $PUBLISH_TO/twiki/components/kernel/"
	@echo "make publish_extensions - upload built extensions to $PUBLISH_TO/twiki/components/extension/"
	@echo 
	@echo "make twiki-install - builds the installation webscript"
	@echo 
	@echo ================================================================================
	@echo build-options:
	@echo   MakeFor - distribution name
