#!/bin/bash

set -euo pipefail

export HOME=/var
export TMPDIR=/var/tmp
export TZ=Etc/UTC
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
VENV=/opt/app-venv
export PATH="$VENV/bin:$PATH"

rm -rf /var/lock
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
test -e /var/VERSION || touch /var/VERSION
[[ "$(cat /var/VERSION)" == "0.7.1" ]] && (cd /opt/mediagoblin && ./bin/gmg alembic current && echo "Stamping Database...." && ./bin/gmg alembic stamp 52bf0ccbedc1)
[[ "$(cat /var/VERSION)" == "0.15.0" ]] || (cd /opt/mediagoblin && echo "Upgrading Database...."  && ./bin/gmg dbupdate && echo "0.15.0" > /var/VERSION)

cd /opt/mediagoblin
./lazyserver.sh --server-name=broadcast 2>&1
