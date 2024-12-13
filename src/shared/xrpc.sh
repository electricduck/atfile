#!/usr/bin/env bash

# PDS

function atfile.xrpc.pds.blob() {
    file="$1"
    type="$2"
    lexi="$3"

    [[ -z $lexi ]] && lexi="com.atproto.repo.uploadBlob"
    [[ -z $type ]] && type="*/*"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(atfile.xrpc.pds.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        --data-binary @"$file" | jq
}

function atfile.xrpc.pds.get() {
    lexi="$1"
    query="$2"
    type="$3"
    endpoint="$4"

    [[ -z $type ]] && type="application/json"
    [[ -z $endpoint ]] && endpoint="$_server"

    curl -s -X GET $endpoint/xrpc/$lexi?$query \
        -H "Authorization: Bearer $(atfile.xrpc.pds.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \ | jq
}

function atfile.xrpc.pds.jwt() {
    curl -s -X POST $_server/xrpc/com.atproto.server.createSession \
        -H "Content-Type: application/json" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -d '{"identifier": "'$_username'", "password": "'$_password'"}' | jq -r ".accessJwt"
}

function atfile.xrpc.pds.post() {
    lexi="$1"
    data="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(atfile.xrpc.pds.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -d "$data" | jq
}

# AppView

## Bluesky

function atfile.xrpc.bsky.get() {
    lexi="$1"
    query="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X GET $_endpoint_appview_bsky/xrpc/$lexi?$query \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" | jq 
}

## Bluesky Video

function atfile.xrpc.bsky_video.jwt() {
    lxm="$1"
    aud="$2"

    [[ -z "$aud" ]] && aud="did:web:$(atfile.util.get_uri_segment "$_endpoint_appview_bsky_video" host)"

    atfile.xrpc.pds.get "com.atproto.server.getServiceAuth" "aud=$aud&lxm=$lxm" | jq -r ".token"
}

function atfile.xrpc.bsky_video.get() {
    lexi="$1"
    query="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X GET $_endpoint_appview_bsky_video/xrpc/$lexi?$query \
        -H "Authorization: Bearer $(atfile.xrpc.bsky_video.jwt "$lexi")" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" | jq 
}
