#!/usr/bin/env bash

# app.bsky.video.*

## Queries

function app.bsky.video.getJobStatus() {
    id="$1"

    atfile.xrpc.bsky_video.get "app.bsky.video.getJobStatus" "jobId=$id"
}

function app.bsky.video.getUploadLimits() {
    atfile.xrpc.bsky_video.get "app.bsky.video.getUploadLimits"
}

function app.bsky.video.uploadVideo() {
    file="$1"

    aud="did:web:$(atfile.util.get_uri_segment "$_server" host)"
    did="$_username"
    name="$(basename "$file")"
    type="video/mp4"

    curl -s -X POST $_endpoint_appview_bsky_video/xrpc/app.bsky.video.uploadVideo?did=$did\&name=$name \
        -H "Authorization: Bearer $(atfile.xrpc.bsky_video.jwt "com.atproto.repo.uploadBlob" "$aud")" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        --data-binary @"$file" | jq
}
