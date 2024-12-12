#!/usr/bin/env bash

# app.bsky.*

## Queries

function app.bsky.actor.getProfile() {
    actor="$1"
    
    atfile.xrpc.bsky.get "app.bsky.actor.getProfile" "actor=$actor"
}

function app.bsky.labeler.getServices() {
    did="$1"
    
    atfile.xrpc.bsky.get "app.bsky.labeler.getServices" "dids=$did"
}
