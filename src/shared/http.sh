#!/usr/bin/env bash

function atfile.http.download() {
    uri="$1"
    out_path="$2"

    atfile.say.debug "$uri\n↳ $out_path" "GET:   "

    curl -s -X GET "$uri" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -o "$out_path"
}

function atfile.http.get() {
    uri="$1"
    auth="$2"
    type="$3"

    [[ -n $auth ]] && auth="Authorization: $auth"
    [[ -z $type ]] && type="application/json"

    atfile.say.debug "$uri" "GET:   "
    
    curl -s -X GET "$uri" \
        -H "$auth" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)"
}

function atfile.http.post() {
    uri="$1"
    data="$2"
    auth="$3"
    type="$4"

    [[ -n $auth ]] && auth="Authorization: $auth"
    [[ -z $type ]] && type="application/json"

    atfile.say.debug "$uri\n↳ $data" "POST:  "

    curl -s -X POST "$uri" \
        -H "$auth" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -d "$data"
}

function atfile.http.upload() {
    uri="$1"
    file="$2"
    auth="$3"
    type="$4"

    [[ -n $auth ]] && auth="Authorization: $auth"
    [[ -z $type ]] && type="*/*"

    atfile.say.debug "$uri\n↳ $file" "POST:  "

    curl -s -X POST $_server/xrpc/$lexi \
        -H "$auth" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        --data-binary @"$file" | jq
}
