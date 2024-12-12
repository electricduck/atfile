#!/usr/bin/env bash

function atfile.stream() {
    collection="$1"
    did="$2"
    cursor="$3"
    compress="$4"

    atfile.util.check_prog "websocat" "https://github.com/vi/websocat"

    [[ "$compress" == 1 ]] && compress="true"

    atfile.say.debug "Streaming: $_endpoint_jetstream\n↳ Collection: $(echo "$collection" | sed -s 's/;/, /g')\n↳ DID: $(echo "$did" | sed -s 's/;/, /g')\n↳ Cursor: $cursor\n↳ Cursor: $compress"

    collection_query="$(atfile.util.build_query_array "wantedCollections" "$collection")"
    did_query="$(atfile.util.build_query_array "wantedDids" "$did")"
    cursor_query="$([[ -n "$cursor" ]] && echo "cursor=$cursor&")"
    compress_query="$([[ -n "$compress" ]] && echo "compress=$compress&")"

    url="$_endpoint_jetstream/subscribe?${collection_query}${did_query}${cursor_query}${compress_query}"
    url="${url::-1}"

    atfile.say.debug "Using URL '$url'"

    websocat "${url}"
}
