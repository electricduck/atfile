#!/usr/bin/env bash

function atfile.http.download() {
    uri="$1"
    out_path="$2"

    curl -s -X GET "$uri" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -o "$out_path"
}

function atfile.http.get() {
    uri="$1"
    
    curl -s -X GET "$uri" \
        -H "User-Agent: $(atfile.util.get_uas)"
}
