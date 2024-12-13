#!/usr/bin/env bash

# TODO: Validate checksum
function atfile.update() {
    cmd="$1"
    unset error

    if [[ "$cmd" == "check-only" ]]; then
        [[ $_disable_update_checking == 1 ]] && return
        [[ $_disable_updater == 1 ]] && return
        [[ $_is_git == 1 && $_enable_update_git_clobber == 0 ]] && return
        [[ $_output_json == 1 ]] && return

        last_checked="$(atfile.cache.get "update-check")"
        current_checked="$(atfile.util.get_date "" "%s")"
        check_sleep=3600
        next_check=$(( $last_checked + $check_sleep ))

        atfile.say.debug "Checking for last update check...\n↳ Last: $last_checked\n↳ Cur.: $current_checked\n↳ Next: $next_check"

        if [[ $(( $next_check < $current_checked )) == 0 ]]; then
            return
        else
            last_checked="$(atfile.cache.set "update-check" "$current_checked")"
        fi
    fi

    [[ $_output_json == 1 ]] && atfile.die "Command not available as JSON"

    update_did="$_dist_username"

    atfile.util.override_actor "$update_did"
    atfile.util.print_override_actor_debug

    atfile.say.debug "Getting latest release..."
    latest_release_record="$(com.atproto.repo.getRecord "$update_did" "self.atfile.latest" "self")"
    error="$(atfile.util.get_xrpc_error $? "$latest_release_record")"

    [[ -n "$error" ]] && atfile.die "Unable to get latest version" "$error"

    latest_version="$(echo "$latest_release_record" | jq -r '.value.version')"
    latest_version_commit="$(echo "$latest_release_record" | jq -r '.value.commit')"
    latest_version_date="$(echo "$latest_release_record" | jq -r '.value.releasedAt')"
    parsed_latest_version="$(atfile.util.parse_version $latest_version)"
    parsed_running_version="$(atfile.util.parse_version $_version)"
    latest_version_record_id="atfile-$parsed_latest_version"
    update_available=0
    
    atfile.say.debug "Checking version...\n↳ Latest: $latest_version ($parsed_latest_version)\n ↳ Date: $latest_version_date\n ↳ Commit: $latest_version_commit\n↳ Running: $_version ($parsed_running_version)"

    if [[ $(( $parsed_latest_version > $parsed_running_version )) == 1 ]]; then
        update_available=1
    fi

    case "$cmd" in
        "check-only")
            if [[ $update_available == 0 ]]; then
                atfile.say.debug "No updates found"
                return
            fi

            echo "---"
            if [[ $_os == "haiku" ]]; then
                atfile.say "Update available ($latest_version)\n↳ Run \`$_prog update\` to update" # BUG: Haiku Terminal has issues with emojis
            else
                atfile.say "😎 Update available ($latest_version)\n  ↳ Run \`$_prog update\` to update"
            fi
            ;;
        "install")
            if [[ $update_available == 0 ]]; then
                atfile.say "No updates found"
                return
            fi

            [[ $_is_git == 1 && $_enable_update_git_clobber == 0 ]] &&\
                atfile.die "Cannot update in Git repository"
            [[ $_disable_updater == 1 ]] &&\
                atfile.die "Cannot update system-managed version: update from your package manager" # NOTE: This relies on packaged versions having a wrapper that sets this var

            temp_updated_path="$_prog_dir/${_prog}-${latest_version}.tmp"
            
            atfile.say.debug "Touching temporary path ($temp_updated_path)..."
            touch "$temp_updated_path"
            [[ $? != 0 ]] && atfile.die "Unable to create temporary file (do you have permission?)"
            
            atfile.say.debug "Getting blob URL for $latest_version ($latest_version_record_id)..."
            blob_url="$(atfile.invoke.get_url $latest_version_record_id)"
            [[ $? != 0 ]] && atfile.die "Unable to get blob URL"
            blob_url="$(echo -e "$blob_url" | tail -n 1)" # HACK: ATFILE_DEBUG=1 screws up output, so we'll `tail` for safety

            atfile.say.debug "Downloading latest release..."
            curl -H "User-Agent: $(atfile.util.get_uas)" -s -o "$temp_updated_path" "$blob_url"
            if [[ $? == 0 ]]; then
                mv "$temp_updated_path" "$_prog_path"
                if [[ $? != 0 ]]; then
                    atfile.die "Unable to update (do you have permission?)"
                else
                    chmod +x "$_prog_path"

                    if [[ $_os == "haiku" ]]; then
                        atfile.say "Updated to $latest_version!" # BUG: Haiku Terminal has issues with emojis
                    else
                        atfile.say "😎 Updated to $latest_version!"
                    fi

                    exit 0
                fi
            else
                atfile.die "Unable to download latest version"
            fi
            ;;
    esac
}
