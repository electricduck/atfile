#!/usr/bin/env bash

function atfile.js.subscribe() {
    collection="$1"

    atfile.util.check_prog "websocat" "https://github.com/vi/websocat"
    websocat "$_endpoint_jetstream/subscribe?wantedCollections=$collection"
}
