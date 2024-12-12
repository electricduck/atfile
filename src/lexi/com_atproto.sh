#!/usr/bin/env bash

# com.atproto.*

## Queries

function com.atproto.repo.createRecord() {
    repo="$1"
    collection="$2"
    record="$3"
    
    atfile.xrpc.pds.post "com.atproto.repo.createRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"record\": $record }"
}

function com.atproto.repo.deleteRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"

    atfile.xrpc.pds.post "com.atproto.repo.deleteRecord" "{ \"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\" }"
}

function com.atproto.repo.getRecord() {
    repo="$1"
    collection="$2"
    key="$3"

    atfile.xrpc.pds.get "com.atproto.repo.getRecord" "repo=$repo&collection=$collection&rkey=$key"
}

function com.atproto.repo.listRecords() {
    repo="$1"
    collection="$2"
    cursor="$3"
    
    atfile.xrpc.pds.get "com.atproto.repo.listRecords" "repo=$repo&collection=$collection&limit=$_max_list&cursor=$cursor"
}

function com.atproto.repo.putRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"
    record="$4"
    
    atfile.xrpc.pds.post "com.atproto.repo.putRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\", \"record\": $record }"
}

function com.atproto.identity.resolveHandle() {
    handle="$1"

    atfile.xrpc.pds.get "com.atproto.identity.resolveHandle" "handle=$handle"
}

function com.atproto.server.getSession() {
    atfile.xrpc.pds.get "com.atproto.server.getSession"
}

function com.atproto.sync.getBlob() {
    did="$1"
    cid="$2"

    atfile.xrpc.pds.get "com.atproto.sync.getBlob" "did=$did&cid=$cid" "*/*"
}

function com.atproto.sync.listBlobs() {
    did="$1"
    cursor="$2"
    
    atfile.xrpc.pds.get "com.atproto.sync.listBlobs" "did=$did&limit=$_max_list&cursor=$cursor"
}

function com.atproto.sync.uploadBlob() {
    file="$1"
    atfile.xrpc.pds.blob "$1" | jq -r ".blob"
}
