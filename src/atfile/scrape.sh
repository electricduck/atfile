#!/usr/bin/env bash

function atfile.scrape() {
    url="$1"
    host="$(atfile.util.get_uri_segment "$url" host)"

    if [[ "$(atfile.util.get_uri_segment "$url" host)" == "bsky.app" || "$(atfile.util.get_uri_segment "$url" host)" == "main.bsky.dev" ]] &&\
       [[ "$(atfile.util.get_uri_segment "$url" 6)" == "post" ]] &&\
       [[ -n "$(atfile.util.get_uri_segment "$url" 7)" ]]; then
        echo "Scrape!"
    else
        atfile.die "Unsupported to scrape URL '$url'"
    fi
}
