#!/bin/sh
if [ -n "$1" ]; then
    UPSTREAM_BASE=$1
else
    UPSTREAM_BASE="../mcbopomofo-core"
fi

set -x

# $2 is pkgdatadir
DATA_DEST="${DESTDIR}/$2/data"

mkdir -p $DATA_DEST
cp $UPSTREAM_BASE/data/data.txt "${DATA_DEST}/mcbopomofo-data.txt"
cp $UPSTREAM_BASE/data/data-plain-bpmf.txt "${DATA_DEST}/mcbopomofo-data-plain-bpmf.txt"
# TODO: icon for desktop file
