#!/usr/bin/env bash

function atfile.resolve() {
    actor="$1"

    [[ -z $actor && -n $_username ]] && actor="$_username"

    atfile.say.debug "Resolving actor '$actor'..."

    resolved_did="$(atfile.util.resolve_identity "$actor")"
    error="$(atfile.util.get_xrpc_error $? "$resolved_did")"
    [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$actor'" "$resolved_did"

    aliases="$(echo $resolved_did | cut -d "|" -f 5)"
    did="$(echo $resolved_did | cut -d "|" -f 1)"
    did_doc="$(echo $resolved_did | cut -d "|" -f 4)/$did"
    did_type="did:$(echo $did | cut -d ":" -f 2)"
    handle="$(echo $resolved_did | cut -d "|" -f 3 | cut -d "/" -f 3)"
    pds="$(echo $resolved_did | cut -d "|" -f 2)"
    pds_name="$(atfile.util.get_pds_pretty "$pds")"
    pds_software="Bluesky PDS"
    atfile.say.debug "Getting PDS version for '$pds'..."
    pds_version="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -l -X GET "$pds/xrpc/_health" | jq -r '.version')"

    if [[ "$pds_version" == *" v"* ]]; then
        pds_software="🐌 $(echo "$pds_version" | sed -s 's/ v/\n/g' | sed -n 1p)"
        pds_version="$(echo "$pds_version" | sed -s 's/ v/\n/g' | sed -n 2p)"

        if [[ "$pds_name" == "$(atfile.util.get_uri_segment "$pds" host)" ]]; then
            pds_name="$pds_software"
        fi
    fi

    case "$did_type" in
        "did:plc")
            # SEE: https://bsky.app/profile/did:web:bhh.sh/post/3lc2jkmhxq225
            #      pls stop breaking my shit, @benharri.org
            [[ $actor == "did:web:"* ]] && did_doc="$(atfile.util.get_didweb_doc_url "$actor")"
            ;;
        "did:web")
            did_doc="$(atfile.util.get_didweb_doc_url "$did")"
            ;;
    esac

    if [[ $_output_json == 1 ]]; then
        did_doc_data="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -l -X GET "$did_doc")"
        aliases_json="$(echo "$did_doc_data" | jq -r ".alsoKnownAs")"

        echo -e "{
    \"aka\": "$aliases_json",
    \"did\": \"$did\",
    \"doc\": {
        \"data\": $did_doc_data,
        \"url\": \"$did_doc\"
    },
    \"handle\": \"$handle\",
    \"pds\": {
        \"endpoint\": \"$pds\",
        \"name\": \"$pds_name\",
        \"software\": {
            \"name\": \"$pds_software\",
            \"version\": \"$pds_version\"
        }
    },
    \"type\": \"$did_type\"
}" | jq
    else
        atfile.say "$did"
        atfile.say "↳ Type: $did_type"
        atfile.say " ↳ Doc: $did_doc"
        atfile.say "↳ Handle: @$handle"

        while IFS=$";" read -ra a; do
            unset first_alias

            for i in "${a[@]}"; do
                if [[ -z "$first_alias" ]]; then
                    atfile.say " ↳ $i"
                else
                    atfile.say "   $i"
                fi

                first_alias="$a"
            done
        done <<< "$aliases"

        atfile.say "↳ PDS: $pds_name"
        atfile.say " ↳ Endpoint: $pds"
        [[ $(atfile.util.is_null_or_empty "$pds_version") == 0 ]] && atfile.say " ↳ Version: $pds_version"
    fi
}
