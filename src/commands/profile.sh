#!/usr/bin/env bash

function atfile.profile() {
    app="$1"
    actor="$2"

    [[ $_output_json == 1 ]] && atfile.die "Command not available as JSON"

    function atfile.profile.get_pretty_date() {
        atfile.util.get_date "$1" "%Y-%m-%d %H:%M:%S"
    }

    function atfile.profile.get_profile_bsky() {
        bsky_profile="$(app.bsky.actor.getProfile "$actor")"
        error="$(atfile.util.get_xrpc_error $? "$bsky_profile")"
        [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to get Bluesky profile for '$actor'" "$bsky_profile"

        bio="$(echo "$bsky_profile" | jq '.description')"
        bio="${bio%\"}"; bio="${bio#\"}"
        count_feeds="$(echo "$bsky_profile" | jq -r '.associated.feedgens')"
        count_followers="$(echo "$bsky_profile" | jq -r '.followersCount')"
        count_following="$(echo "$bsky_profile" | jq -r '.followsCount')"
        count_likes=0
        count_lists="$(echo "$bsky_profile" | jq -r '.associated.lists')"
        count_packs="$(echo "$bsky_profile" | jq -r '.associated.starterPacks')"
        count_posts="$(echo "$bsky_profile" | jq -r '.postsCount')"
        date_created="$(echo "$bsky_profile" | jq -r '.createdAt')"
        date_created="$(atfile.profile.get_pretty_date "$date_created")"
        date_indexed="$(echo "$bsky_profile" | jq -r '.indexedAt')"
        date_indexed="$(atfile.profile.get_pretty_date "$date_indexed")"
        did="$(echo "$bsky_profile" | jq -r '.did')"
        handle="$(echo "$bsky_profile" | jq -r '.handle')"
        name="$(echo "$bsky_profile" | jq -r '.displayName')"
        type="🔵 User"

        if [[ $(atfile.util.is_null_or_empty "$bio") == 1 ]]; then
            bio="(No Bio)"
        else
            bio="$(echo -e "$bio" | fold -sw 78)"
            unset bio_formatted

            while IFS= read -r line; do
                bio_formatted+=" $line\n"
            done <<< "$bio"
        fi

        if [[ "$(echo "$bsky_profile" | jq -r '.associated.labeler')" == "true" ]]; then
            labeler_services="$(app.bsky.labeler.getServices "$did")"

            count_likes="$(echo "$labeler_services" | jq -r '.views[] | select(."$type" == "app.bsky.labeler.defs#labelerView") | .likeCount')"
            type="🟦 Labeler"
        fi

        [[ $(atfile.util.is_null_or_empty "$count_feeds") == 1 ]] && count_feeds="0" || count_feeds="$(atfile.util.fmt_int $count_feeds)"
        [[ $(atfile.util.is_null_or_empty "$count_followers") == 1 ]] && count_followers="0" || count_followers="$(atfile.util.fmt_int $count_followers)"
        [[ $(atfile.util.is_null_or_empty "$count_following") == 1 ]] && count_following="0" || count_following="$(atfile.util.fmt_int $count_following)"
        [[ $(atfile.util.is_null_or_empty "$count_likes") == 1 ]] && count_likes="0" || count_likes="$(atfile.util.fmt_int $count_likes)"
        [[ $(atfile.util.is_null_or_empty "$count_lists") == 1 ]] && count_lists="0" || count_lists="$(atfile.util.fmt_int $count_lists)"
        [[ $(atfile.util.is_null_or_empty "$count_packs") == 1 ]] && count_packs="0" || count_packs="$(atfile.util.fmt_int $count_packs)"
        [[ $(atfile.util.is_null_or_empty "$count_posts") == 1 ]] && count_posts="0" || count_posts="$(atfile.util.fmt_int $count_posts)"
        [[ $(atfile.util.is_null_or_empty "$handle") == 1 ]] && handle="handle.invalid"
        [[ $(atfile.util.is_null_or_empty "$name") == 1 ]] && name="$handle"

        name_length=${#name}

        # Do not modify the spacing here!
        bsky_profile_output="
  \e[1;37m$name\e[0m
  \e[37m$(atfile.util.repeat_char "-" $name_length)\e[0m
 $bio_formatted \e[37m$(atfile.util.repeat_char "-" 3)\e[0m
  🔌 @$handle ∙ #️⃣  $did 
  ⬇️  $count_followers $(atfile.util.get_int_suffix $count_followers "\e[37mFollower\e[0m" "\e[37mFollowers\e[0m") ∙ ⬆️  $count_following \e[37mFollowing\e[0m ∙ ⭐️ $count_likes \e[37mLikes\e[0m
  📃 $count_posts $(atfile.util.get_int_suffix $count_followers "\e[37mPost\e[0m" "\e[37mPosts\e[0m") ∙ ⚙️  $count_feeds $(atfile.util.get_int_suffix $count_feeds "\e[37mFeed\e[0m" "\e[37mFeeds\e[0m") ∙ 📋 $count_lists $(atfile.util.get_int_suffix $count_lists "\e[37mList\e[0m" "\e[37mLists\e[0m") ∙ 👥 $count_packs $(atfile.util.get_int_suffix $count_packs "\e[37mPack\e[0m" "\e[37mPacks\e[0m")
  $type ∙ ✨ $date_created ∙ 🕷️  $date_indexed
  \e[37m$(atfile.util.repeat_char "-" 3)\e[0m
  🦋 https://bsky.app/profile/$actor\n"

        if [[ "$date_indexed" == "0001-01-01 00:00:00" ]]; then
            atfile.die "No Bluesky profile for '$actor'"
        else
            atfile.say "$bsky_profile_output"
        fi
    }

    function atfile.profile.get_profile_fyi() {
        bsky_profile="$(app.bsky.actor.getProfile "$actor")"
        error="$(atfile.util.get_xrpc_error $? "$bsky_profile")"
        [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to get Frontpage profile for '$actor'" "$bsky_profile"

        did="$(echo "$bsky_profile" | jq -r '.did')"
        handle="$(echo "$bsky_profile" | jq -r '.handle')"
        name="$(echo "$bsky_profile" | jq -r '.handle')"

        name_length=${#name}

        fyi_profile_output="
  \e[1;37m$name\e[0m
  \e[37m$(atfile.util.repeat_char "-" $name_length)\e[0m
  🔌 @$handle ∙ #️⃣  $did
  \e[37m$(atfile.util.repeat_char "-" 3)\e[0m
  📃 https://frontpage.fyi/profile/$actor\n"

        atfile.say "$fyi_profile_output"
    }

    if [[ -z "$actor" ]]; then
        actor="$_username"
    else
        resolved_did="$(atfile.util.resolve_identity "$actor")"
        error="$(atfile.util.get_xrpc_error $? "$resolved_did")"
        [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$actor'" "$resolved_did"
    
        actor="$(echo $resolved_did | cut -d "|" -f 1)"
    fi

    case "$app" in
        "bsky")
            atfile.say.debug "Getting Bluesky profile for '$actor'..."
            atfile.profile.get_profile_bsky "$actor"
            ;;
        "fyi")
            atfile.say.debug "Getting Frontpage profile for '$actor'..."
            atfile.profile.get_profile_fyi "$actor"
            ;;
    esac
}
