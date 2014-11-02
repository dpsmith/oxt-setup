#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOURCES="${DIR}/sources"

if [ -d ${SOURCES}/bitbake ]; then
    for p in ${DIR}/patches/bitbake/*.patch; do
        if [ ! -f "${p}.APPLIED" ]; then
            echo "Applying BitBake patch: $p"
            pushd ${SOURCES}/bitbake
            git apply $p || true
            popd
            touch "${p}.APPLIED"
        fi
    done
fi
