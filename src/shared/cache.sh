#!/usr/bin/env bash

function atfile.cache.del() {
    key="$(atfile.util.get_cache_path $1)"
    [[ -f "$key" ]] && rm "$key"
}

function atfile.cache.get() {
    key="$(atfile.util.get_cache_path $1)"
    [[ -f "$key" ]] && cat "$key"
}

function atfile.cache.set() {
    key="$(atfile.util.get_cache_path $1)"
    value="$2"

    mkdir -p "$_path_cache"
    echo "$value" > "$key"
    echo "$value"
}
