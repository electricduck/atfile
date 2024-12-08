#!/usr/bin/env bash

# Functions

function atfile.devel.die() {
    echo -e "\033[1;31mError: $1\033[0m"
    exit 255
}

function atfile.devel.get_source_path() {
    prefix="$ATFILE_DEVEL_DIR/src"
    echo "$prefix/$1.sh"
}

# Variables

ATFILE_DEVEL=1
ATFILE_DEVEL_DIR="$(dirname "$(realpath "$0")")"
ATFILE_DEVEL_ENTRY="$(realpath "$0")"

# Main

source "$(atfile.devel.get_source_path "sources")"

for s in "${ATFILE_DEVEL_SOURCES[@]}"
do
    path="$(atfile.devel.get_source_path "$s")"

    if [[ ! -f "$path" ]]; then
        atfile.devel.die "Unable to find source for '$s'"
    fi

    source "$path"
done
