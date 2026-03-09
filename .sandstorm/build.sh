#!/bin/bash
set -euo pipefail

export TZ=Etc/UTC
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

export PIP_CACHE_DIR=/var/tmp/pip-cache
mkdir -p "$PIP_CACHE_DIR"
BUILD_STATE_DIR=/var/tmp/mediagoblin-build-state
mkdir -p "$BUILD_STATE_DIR"

VENV=/opt/app-venv
if [ ! -d $VENV ] ; then
    sudo mkdir -p $VENV -m777
    virtualenv $VENV
else
    echo "$VENV exists, moving on"
fi

if [ ! -e /opt/mediagoblin ]; then
    sudo install -d -m 775 -o "$(id -u)" -g "$(id -g)" /opt/mediagoblin
    git clone https://git.sr.ht/~mediagoblin/mediagoblin /opt/mediagoblin
    git config --global --add safe.directory /opt/mediagoblin
fi

if [ -d /opt/mediagoblin ] && [ ! -w /opt/mediagoblin ]; then
    echo "/opt/mediagoblin is not writable; fixing ownership"
    sudo chown -R "$(id -u):$(id -g)" /opt/mediagoblin
fi

# Upstream setup.cfg can reference mediagoblin.__version__, which may be missing.
# Pin a local version string for the dev package build path.
if grep -Eq '^version[[:space:]]*=[[:space:]]*attr:[[:space:]]*mediagoblin\.__version__[[:space:]]*$' /opt/mediagoblin/setup.cfg ; then
    sudo sed -i -E 's/^version[[:space:]]*=[[:space:]]*attr:[[:space:]]*mediagoblin\.__version__[[:space:]]*$/version = 0+sandstorm/' /opt/mediagoblin/setup.cfg
fi

if [ -f /opt/mediagoblin/requirements.txt ] ; then
    REQS_HASH_FILE="$BUILD_STATE_DIR/requirements.sha256"
    VENV_REQS_HASH_FILE="$VENV/requirements.sha256"

    CURRENT_REQS_HASH="$(sha256sum /opt/mediagoblin/requirements.txt | awk '{print $1}')"
    PREVIOUS_REQS_HASH="$(cat "$REQS_HASH_FILE" 2>/dev/null || true)"
    PREVIOUS_VENV_REQS_HASH="$(cat "$VENV_REQS_HASH_FILE" 2>/dev/null || true)"

    if [ ! -x "$VENV/bin/python" ] || [ ! -x "$VENV/bin/pip" ] ; then
        echo "virtualenv is incomplete; recreating $VENV"
        rm -rf "$VENV"
        virtualenv "$VENV"
    fi

    if [ "$CURRENT_REQS_HASH" != "$PREVIOUS_REQS_HASH" ] || [ "$CURRENT_REQS_HASH" != "$PREVIOUS_VENV_REQS_HASH" ] ; then
        echo "requirements state changed; installing Python deps"
        $VENV/bin/pip install -r /opt/mediagoblin/requirements.txt
        echo "$CURRENT_REQS_HASH" > "$REQS_HASH_FILE"
        echo "$CURRENT_REQS_HASH" > "$VENV_REQS_HASH_FILE"
    else
        echo "requirements.txt unchanged; skipping pip install"
    fi
fi

cd /opt/mediagoblin
mkdir -p /opt/mediagoblin/mediagoblin/plugins/sandstorm
cp -f -r /opt/app/auth-plugin/* /opt/mediagoblin/mediagoblin/plugins/sandstorm/
sudo ln -sfn /var/mediagoblin.ini /opt/mediagoblin/mediagoblin.ini
sudo ln -sfn /var/user_dev /opt/mediagoblin/user_dev

# `setup.py develop` rewrites metadata under *.egg-info.
# If a previous run created those paths as root, repair ownership.
if [ -d /opt/mediagoblin/mediagoblin.egg-info ] && [ ! -w /opt/mediagoblin/mediagoblin.egg-info/PKG-INFO ]; then
    echo "mediagoblin.egg-info is not writable; fixing ownership"
    sudo chown -R "$(id -u):$(id -g)" /opt/mediagoblin/mediagoblin.egg-info
fi

"$VENV/bin/python" setup.py develop

AUTOTOOLS_HASH_FILE="$BUILD_STATE_DIR/autotools-inputs.sha256"
AUTOTOOLS_INPUTS="$(
    {
        [ -f configure.ac ] && echo "configure.ac"
        find . -type f -name 'Makefile.am' | sed 's|^\./||'
        find m4 -type f -name '*.m4' 2>/dev/null | sed 's|^\./||'
    } | sort
)"
CURRENT_AUTOTOOLS_HASH="$(
    {
        echo "$AUTOTOOLS_INPUTS"
        for file in $AUTOTOOLS_INPUTS; do
            sha256sum "$file"
        done
    } | sha256sum | awk '{print $1}'
)"
PREVIOUS_AUTOTOOLS_HASH="$(cat "$AUTOTOOLS_HASH_FILE" 2>/dev/null || true)"

if [ "$CURRENT_AUTOTOOLS_HASH" != "$PREVIOUS_AUTOTOOLS_HASH" ] ; then
    echo "autotools inputs changed; running autogen/configure"
    sudo ./autogen.sh
    ./configure
    echo "$CURRENT_AUTOTOOLS_HASH" > "$AUTOTOOLS_HASH_FILE"
elif [ ! -x ./configure ] || [ ! -f Makefile ] ; then
    echo "autotools outputs missing; running autogen/configure"
    sudo ./autogen.sh
    ./configure
    echo "$CURRENT_AUTOTOOLS_HASH" > "$AUTOTOOLS_HASH_FILE"
else
    echo "autotools inputs unchanged; skipping autogen/configure"
fi

sudo make
