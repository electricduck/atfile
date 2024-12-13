#!/usr/bin/env bash

function atfile.cache.get() {
    key="$1"

    key_path="$_path_cache/$key"

    if [[ -f "$key_path" ]]; then
        cat "$key_path"
    fi
}

function atfile.cache.set() {
    key="$1"
    value="$2"

    mkdir -p "$_path_cache"
    key_path="$_path_cache/$key"

    echo "$value" > "$key_path"
    echo "$value"
}
