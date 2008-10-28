#! /bin/sh

ACCOUNT=$1

if ! [ -d /home/$ACCOUNT ];
then
	echo Creating and initialising '$ACCOUNT' user account
	sudo adduser --disabled-password --gecos $ACCOUNT $ACCOUNT
	sudo usermod -G www-data $ACCOUNT;
fi

if ! [ -d /home/$ACCOUNT/.ssh ];
then
	echo Installing SSH keys;
	sudo mkdir /home/$ACCOUNT/.ssh
	sudo chmod 700 /home/$ACCOUNT/.ssh
	sudo cp ~/.ssh/id_dsa.pub /home/$ACCOUNT/.ssh/authorized_keys
	sudo chmod 600 /home/$ACCOUNT/.ssh/authorized_keys
	sudo chown -R $ACCOUNT.$ACCOUNT /home/$ACCOUNT/.ssh
fi

if [ -d /home/$ACCOUNT/public_html/cgi-bin/twiki ]
then
	echo Removing previous TWiki installation
	sudo rm -rf /home/$ACCOUNT/public_html/cgi-bin/twiki
fi

echo Creating web directory structure
sudo -u $ACCOUNT mkdir -p /home/$ACCOUNT/public_html/cgi-bin
sudo -u $ACCOUNT chmod g+w /home/$ACCOUNT/public_html/cgi-bin
sudo chgrp -R www-data /home/$ACCOUNT/public_html;

echo Installing...
time bin/install-twiki.pl \
    --TWikiFor=http://TWikiFor.twiki.org/~twikibuilder/twiki/twiki.org.zip \
	--dir=$ACCOUNT@`hostname`:~/public_html/cgi-bin \
	--url=http://`hostname`/~$ACCOUNT/cgi-bin/twiki-install.cgi \
	--extension=CpanContrib \
	$EXTENSIONS \
