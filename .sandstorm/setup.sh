#!/bin/bash

# When you change this file, you must take manual action. Read this doc:
# - https://docs.sandstorm.io/en/latest/vagrant-spk/customizing/#setupsh

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y nginx uwsgi uwsgi-plugin-python3 build-essential python3-setuptools python3-dev python3-virtualenv git libxml2-dev libxslt1-dev python3-lxml python-pil libtiff5-dev libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk python3-numpy python3-npx python3-scipy python3-pip python3-venv python3-full automake gawk nodejs npm

service nginx stop
systemctl disable nginx
