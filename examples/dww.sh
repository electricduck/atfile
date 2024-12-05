#!/usr/bin/env bash

# Sourcing

unset _atfile_path

if [[ -d "$(basename "$(realpath "$0")")/../.git" ]]; then
    _atfile_path="../atfile.sh"
else
    _atfile_path="$(which atfile)"
    [[ $? != 0 ]] && unset _atfile_path
fi

if [[ -f "$_atfile_path" ]]; then
    source "$_atfile_path"
else
    echo -e "\033[1;31mError: ATFile not found\033[0m"
    exit 0
fi

# Die

function dww.die() {
    message="$1"
    atfile.say.die "$message"
    exit 255
}

# Utils

function dww.util.get_at_stats_json() {
    stats="$(atfile.http.get "https://raw.githubusercontent.com/mary-ext/atproto-scraping/refs/heads/trunk/state.json")"
    [[ $? == 0 ]] && echo "$stats" | jq
}

function dww.util.get_bsky_user_count() {
    stats="$(atfile.http.get "https://bsky-stats.lut.li")"
    [[ $? == 0 ]] && echo "$stats" | jq '.total_users'
}

function dww.util.get_change_phrase() {
    type="$1"

    case $type in
        "high-score") echo "🥳" ;;
        "upward") echo "😁" ;;
        "steady") echo "😊" ;;
        "downward") echo "😞" ;;
        *) echo "🤔" ;;
    esac
}

function dww.util.get_dw_stats() {
    didwebs="$(dww.util.get_at_stats_json | jq -c '.firehose.didWebs | to_entries[]')"
    updatedAt="$(dww.util.get_at_stats_json | jq -c '.firehose.cursor')"
    
    active_count=0
    error_count=0
    pds_count=0
    pds_list=()
    unset pds_top

    while IFS=$"\n" read -r a; do
        error_at="$(echo "$a" | jq -r ".value.errorAt")"
        pds="$(echo "$a" | jq -r ".value.pds")"
        
        if [[ $error_at != "null" ]]; then
            ((error_count++))
        else
            ((active_count++))
        fi

        [[ $pds != "null" ]] && pds_list+=("$pds")
    done <<< "$didwebs"

    pds_list_string="$(printf '%s\n' "${pds_list[@]}" | sort | uniq -c | sort -k1,1nr -k2)"
    pds_count="$(echo -e "$pds_list_string" | wc -l)"

    if [[ -n $pds_list ]]; then
        while IFS=$"\n" read -r a; do
            pds_top+="$(echo $a | cut -d " " -f 2);"
        done <<< "$(printf '%s\n' "${pds_list[@]}" | sort | uniq -c | sort -k1,1nr -k2 | head -n3)"
    fi

    echo "$active_count|$error_count|$pds_top|$pds_count|${updatedAt::-6}"
}

function dww.util.get_dw_stats_current_json() {
    stats_record="$(com.atproto.repo.getRecord "$_username" "$_stats_record_nsid" "self")"
    [[ -z "$(atfile.util.get_xrpc_error $? "$stats_record")" ]] && echo "$stats_record"
}

function dww.util.fmt_int() {
    printf "%'d\n" "$1"
}

# Main Functions

function dww.auth() {
    [[ -z "$_atf_username" ]] && dww.die "\$DWW_USERNAME not set"
    [[ -z "$_atf_password" ]] && dww.die "\$DWW_PASSWORD not set"
    atfile.auth "$_atf_username" "$_atf_password"
}

function dww.bot() {
    echo "👀 Checking for update..."

    bsky_users="$(dww.util.get_bsky_user_count)"
    dw_stats="$(dww.util.get_dw_stats)"
    dw_stats_current="$(dww.util.get_dw_stats_current_json)"

    change_phrase="$(dww.util.get_change_phrase "unknown")"
    dw_cursor="$(echo $dw_stats | cut -d "|" -f 5)"
    dw_nodes_top="$(echo $dw_stats | cut -d "|" -f 3)"
    dw_nodes_total="$(echo $dw_stats | cut -d "|" -f 4)"
    dw_users_active="$(echo $dw_stats | cut -d "|" -f 1)"
    dw_users_active_prev=0
    dw_users_errors="$(echo $dw_stats | cut -d "|" -f 2)"
    dw_users_max=0
    is_error=0
    is_update=1

    if [[ $_force_users_active != 0 || $_force_nodes_total != 0 ]]; then
        dw_cursor="$(date +%s)"

        [[ $_force_users_active != 0 ]] && dw_users_active=$_force_users_active
        [[ $_force_nodes_total != 0 ]] && dw_nodes_total=$_force_nodes_total
    fi

    dw_cursor_pretty="$(date -d @$dw_cursor +"%d-%b-%Y %H:%M:%S %:z")"
    dw_users_total=$(( $dw_users_active + $dw_users_errors ))
    dw_dist="$(echo "scale=7; ($dw_users_total / $bsky_users) * 100" | bc)"
    IFS=';' read -r -a dw_nodes_top_array <<< "$dw_nodes_top"

    [[ -z "$bsky_users" || "$bsky_users" == 0 || "$bsky_users" == "null" ]] && is_error=1
    [[ -z "$dw_stats" ]] && is_error=1
    [[ $dw_nodes_total == 0 ]] && is_error=1
    [[ $dw_users_active == 0 ]] && is_error=1

    if [[ -n $dw_stats_current ]]; then
        dw_users_max="$(echo "$dw_stats_current" | jq -r ".value.users.max")"
        dw_users_active_prev="$(echo "$dw_stats_current" | jq -r ".value.users.active")"
        cursor_current="$(echo "$dw_stats_current" | jq -r ".value.cursor")"

        if (( $dw_cursor <= $cursor_current )); then
            is_update=0
        fi
    fi

    (( $dw_users_total > $dw_users_max )) && dw_users_max=$dw_users_total
    [[ $dw_dist == "."* ]] && dw_dist="0$dw_dist"

    if (( $dw_users_total >= $dw_users_max )); then
        change_phrase="$(dww.util.get_change_phrase "high-score")"
    elif (( $dw_users_active == $dw_users_active_prev )); then
        change_phrase="$(dww.util.get_change_phrase "steady")"
    elif (( $dw_users_active > $dw_users_active_prev )); then
        change_phrase="$(dww.util.get_change_phrase "upward")"
    elif (( $dw_users_active < $dw_users_active_prev )); then
        change_phrase="$(dww.util.get_change_phrase "downward")"
    fi

    stats_record="{
        \"cursor\": \"$dw_cursor\",
        \"nodes\": {
            \"top_hosts\": [],
            \"total\": $dw_nodes_total
        },
        \"users\": {
            \"active\": $dw_users_active,
            \"errors\": $dw_users_errors,
            \"max\": $dw_users_max
        }
    }"

    unset post_message_facets
    post_message="did:web Stats $change_phrase\n—\n👥  Users: $(dww.fmt_int $dw_users_active) Active · $(dww.fmt_int $dw_users_errors) Errors · $(dww.fmt_int $dw_users_max) Max\n🖥️  Nodes: $(dww.fmt_int $dw_nodes_total) Total\n ↳ Top: "

    if [[ -n $dw_nodes_top ]]; then
        for a in "${dw_nodes_top_array[@]}"; do
            facet_byte_start=$(( $(echo -e "$post_message" | wc -c) - 1))

            host="$(atfile.util.get_uri_segment "$a" host)"
            post_message+="$host, "

            facet_byte_end=$(( $(echo -e "$post_message" | wc -c) - 3 ))

            post_message_facets+="{
        \"index\": {
            \"byteStart\": $facet_byte_start,
            \"byteEnd\": $facet_byte_end
        },
        \"features\": [
            {
                \"\$type\": \"app.bsky.richtext.facet#link\",
                \"uri\": \"https://pdsls.dev/$host\"
            }
        ]
    },"
        done
    else
        post_message+="(None)"
    fi

    post_message="${post_message::-2}"
    post_message+="\n↔️  Distrib.: $dw_dist% ($(dww.fmt_int $bsky_users) Total)\n—\n📅  Updated: $dw_cursor_pretty"
    post_message_facets="${post_message_facets::-1}"

    post_record="{
        \"createdAt\": \"$(atfile.util.get_date)\",
        \"langs\": [\"en\"],
        \"facets\": [
            {
                \"index\": {
                    \"byteStart\": 0,
                    \"byteEnd\": 13
                },
                \"features\": [
                    {
                        \"\$type\": \"app.bsky.richtext.facet#tag\",
                        \"tag\": \"blueskystats\"
                    }
                ]
            },
            $post_message_facets
        ],
        \"text\": \"$post_message\"
    }"

    echo "---
ℹ️  Update: $dw_cursor_pretty
   Phrase: $change_phrase
   Nodes: $(dww.fmt_int $dw_nodes_total)
   ↳ Top: $(echo "${dw_nodes_top::-1}" | sed -e 's/;/, /g' -e 's/\///g' -e 's/https://g')
   Users: $(dww.fmt_int $dw_users_total)
   ↳ Active: $(dww.fmt_int $dw_users_active)
   ↳ Errors: $(dww.fmt_int $dw_users_errors)
   ↳ Max: $(dww.fmt_int $dw_users_max)
   Dist: $dw_dist%
   ↳ Total: $(dww.fmt_int $bsky_users)
---"

    if [[ $is_error == 0 ]] && [[ $_force_update == 1 ]] || [[ $is_update == 1 ]]; then
        echo -e "✅ Posting update for $dw_cursor_pretty...\n---"

        if [[ $_dry_run == 0 ]]; then
            com.atproto.repo.createRecord "$_username" "app.bsky.feed.post" "$post_record"
            [[ $? != 0 ]] && is_error=1

            com.atproto.repo.putRecord "$_username" "$_stats_record_nsid" "self" "$stats_record"
            [[ $? != 0 ]] && is_error=1
        else
            echo -e "(Dry Run)"
        fi
        
        echo "---"
    else
        echo -e "❌ Skipping update (outdated?)"
    fi

    if [[ $is_error == 1 ]]; then
        dww.bot_error
        exit 0
    fi
}

function dww.bot_error() {
    echo -e "⚠️  Sending error message...\n---"

    error_post_record="{
        \"createdAt\": \"$(atfile.util.get_date)\",
        \"langs\": [\"en\"],
        \"facets\": [
            {
                \"index\": {
                    \"byteStart\": 0,
                    \"byteEnd\": 6
                },
                \"features\": [
                    {
                        \"\$type\": \"app.bsky.richtext.facet#mention\",
                        \"did\": \"did:web:zio.sh\"
                    }
                ]
            }
        ],
        \"text\": \"⚠️ Something went wrong during an update. Service has been paused.\"
    }"

    com.atproto.repo.createRecord "$_username" "app.bsky.feed.post" "$error_post_record"
}

dww.reset() {
    echo "🗑️ Deleting stats...\n---"
    com.atproto.repo.deleteRecord "$_username" "$_stats_record_nsid" "self"
    echo "---"
}

# Main

_sleep_default=43200

_atf_password="$(atfile.util.get_envvar "DWW_PASSWORD")"
_atf_username="$(atfile.util.get_envvar "DWW_USERNAME")"
_delete_stats="$(atfile.util.get_envvar "DWW_DELETE_STATS" 0)"
_dry_run="$(atfile.util.get_envvar "DWW_DRY_RUN" 0)"
_force_users_active="$(atfile.util.get_envvar "DWW_FORCE_USERS_ACTIVE" 0)"
_force_nodes_total="$(atfile.util.get_envvar "DWW_FORCE_NODES_TOTAL" 0)"
_force_update="$(atfile.util.get_envvar "DWW_FORCE_UPDATE" 0)"
_sleep="$(atfile.util.get_envvar "DWW_SLEEP" 43200)"
_stats_record_nsid="self.dww.stats"

if [[ $_command == "help" || $_command == "h" || $_command == "--help" || $_command == "-h" ]]; then
    echo -e "did:web:watch
    Keeping a watchful eye over Bluesky's minority
    
Usage
    $_prog
    
Environment Variables
    DWW_USERNAME <string> (required)
    DWW_PASSWORD <string> (required)
    DWW_DELETE_STATS <bool> (default: 0)
    DWW_DRY_RUN <bool> (default: 0)
    DWW_FORCE_USERS_ACTIVE <int> (default: 0)
    DWW_FORCE_NODES_TOTAL <int> (default: 0)
    DWW_FORCE_UPDATE <bool> (default: 0)
    DWW_SLEEP <int> (default: $_sleep_default)
    "
 
    exit 0
fi

dww.auth

if [[ $_delete_stats == 1 ]]; then
    dww.reset
fi

while true; do
    dww.main
    sleep $_sleep
done
