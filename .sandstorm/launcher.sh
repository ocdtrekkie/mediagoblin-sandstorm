#!/bin/bash

set -euo pipefail

export HOME=/var
export TMPDIR=/var/tmp
VENV=/opt/app-venv
export PATH="$VENV/bin:$PATH"

rm -rf $TMPDIR
mkdir -p $TMPDIR
mkdir -p /var/log
rm -rf /var/run
mkdir -p /var/run
mkdir -p /var/celery
test -e /var/mediagoblin.ini || cp /opt/app/mediagoblin_local.ini /var/mediagoblin.ini
mkdir -p /var/user_dev
mkdir -p /var/user_dev/media/public/media_entries && mkdir -p /var/user_dev/media/queue/media_entries

# Version migration
test -e /var/VERSION || echo "0.7.0" > /var/VERSION
[[ "$(cat /var/VERSION)" == "0.15.0" ]] || (cd /opt/mediagoblin && echo "Upgrading Database...." && ./bin/gmg dbupdate && echo "0.15.0" > /var/VERSION)

cd /opt/mediagoblin
./lazyserver.sh --server-name=broadcast 2>&1
