#!/bin/bash
set -euo pipefail
VENV=/opt/app-venv
if [ ! -d $VENV ] ; then
    sudo mkdir -p $VENV -m777
    virtualenv $VENV
else
    echo "$VENV exists, moving on"
fi

if [ ! -e /opt/mediagoblin ]; then
    sudo git clone https://git.sr.ht/~mediagoblin/mediagoblin /opt/mediagoblin
	sudo git config --global --add safe.directory /opt/mediagoblin
	sudo chmod -R 777 /opt/mediagoblin
fi

if [ -f /opt/mediagoblin/requirements.txt ] ; then
    $VENV/bin/pip install -r /opt/mediagoblin/requirements.txt
fi

cd /opt/mediagoblin
test -L /opt/mediagoblin/mediagoblin.ini || sudo ln -s /var/mediagoblin.ini /opt/mediagoblin/mediagoblin.ini
test -L /opt/mediagoblin/user_dev || sudo ln -s /var/user_dev /opt/mediagoblin/user_dev

sudo python3 setup.py develop

sudo ./autogen.sh && ./configure && sudo make
