#!/usr/bin/env bash
set -e
rm -Rf build-* local-*

if [ "$1" == "all" ]; then
    rm -Rf libffi-*
fi
