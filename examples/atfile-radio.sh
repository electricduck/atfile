#!/usr/bin/env bash

source "../atfile.sh"

library=()
library_item_separator="|"

function get_library_item_fragment() {
    track="$1"
    index="$2"

    echo "$(echo $track | cut -d "${library_item_separator}" -f $index)"
}

while : ; do
    uploads="$(atfile.invoke.list $uploads_cursor)" # BUG: jq error when empty
    [[ $uploads == *"\"error\":"* ]] && break
    uploads_cursor="$(echo $uploads | jq -r '.cursor')"
    uploads_list="$(echo $uploads | jq -c '.uploads[]')"

    while IFS=$"\n" read -r c; do
        key="$(atfile.util.get_rkey_from_at_uri "$(echo $c | jq -r '.uri')")"
        meta_type="$(echo "$c" | jq -r ".value.meta.\"\$type\"")"
        mime="$(echo $c | jq -r '.value.file.mimeType')"
        name="$(echo "$c" | jq -r ".value.file.name")"

        unset artist
        unset title

        if [[ $meta_type == "blue.zio.atfile.meta#audio" ]]; then
            artist="$(echo "$c" | jq -r ".value.meta.tags.artist")"
            title="$(echo "$c" | jq -r ".value.meta.tags.title")"
        fi

        if [[ $mime == audio/* ]]; then
            library+=("${key}${library_item_separator}${artist}${library_item_separator}$title") 
        fi
    done <<< "$uploads_list"
done

library=($(printf "%s\n" "${library[@]}" | shuf))

trap exit SIGINT

for track in "${library[@]}"; do
    key="$(get_library_item_fragment "$track" 1)"
    artist="$(get_library_item_fragment "$track" 2)"
    title="$(get_library_item_fragment "$track" 3)"

    [[ -z "$artist" ]] && artist="(Unknown Artist)"
    [[ -z "$title" ]] && title="(Unknown Track)"

    echo "🎵 [$key] $artist - $title"
    atfile.invoke.print $key | ffplay - -autoexit -hide_banner -loglevel error -nodisp
done

#echo $library
