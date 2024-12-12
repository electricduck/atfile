#!/usr/bin/env bash

# app.bsky.video.*

## Queries

function app.bsky.video.getUploadLimits() {
    atfile.xrpc.bsky_video.get "app.bsky.video.getUploadLimits"
}
