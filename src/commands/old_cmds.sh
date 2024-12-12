#!/usr/bin/env bash

function atfile.invoke.blob_list() {
    cursor="$1"
    unset error
    
    atfile.say.debug "Getting blobs...\n↳ Repo: $_username"
    blobs="$(com.atproto.sync.listBlobs "$_username" "$cursor")"
    error="$(atfile.util.get_xrpc_error $? "$blobs")"

    if [[ -z "$error" ]]; then
        records="$(echo $blobs | jq -c '.cids[]')"
        if [[ -z "$records" ]]; then
            if [[ -n "$cursor" ]]; then
                atfile.die "No more blobs for '$_username'"
            else
                atfile.die "No blobs for '$_username'"
            fi
        fi
    
        unset first_cid
        unset last_cid
        unset browser_accessible
        unset record_count
        unset json_output
    
        if [[ $_output_json == 0 ]]; then
            echo -e "Blob"
            echo -e "----"
        else
            json_output="{\"blobs\":["
        fi
    
        while IFS=$"\n" read -r c; do
            cid="$(echo $c | jq -r ".")"
            blob_uri="$(atfile.util.build_blob_uri "$_username" "$cid")"
            last_cid="$cid"
            ((record_count++))
            
            if [[ -z $first_cid ]]; then
                first_cid="$cid"
                browser_accessible=$(atfile.util.is_url_accessible_in_browser "$blob_uri")
            fi

            if [[ -n $cid ]]; then
                if [[ $_output_json == 1 ]]; then
                    json_output+="{ \"cid\": \"$cid\", \"url\": \"$blob_uri\" },"
                else
                    if [[ $browser_accessible == 1 ]]; then
                        echo "$blob_uri"
                    else
                        echo "$cid"
                    fi
                fi
            fi
        done <<< "$records"
        
        if [[ $_output_json == 0 ]]; then
            atfile.util.print_table_paginate_hint "$last_cid" $record_count
        else
            json_output="${json_output::-1}"
            json_output+="],"
            json_output+="\"browser_accessible\": $(atfile.util.get_yn $browser_accessible),"
            json_output+="\"cursor\": \"$last_cid\"}"
            echo -e "$json_output" | jq
        fi
    else
        atfile.die "Unable to list blobs"
    fi
}

function atfile.invoke.blob_upload() {
    file="$1"

    if [[ ! -f "$file" ]]; then
        atfile.die "File '$file' does not exist"
    else
        file="$(atfile.util.get_realpath "$file")"
    fi

    atfile.say.debug "Uploading blob...\n↳ File: $file"
    com.atproto.sync.uploadBlob "$file" | jq
}

function atfile.invoke.delete() {
    key="$1"
    success=1
    unset error

    lock_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.lock" "$key")"

    if [[ $(echo "$lock_record" | jq -r ".value.lock") == true ]]; then
        atfile.die "Unable to delete '$key' — file is locked\n       Run \`$_prog unlock $key\` to unlock file"
    fi

    record="$(com.atproto.repo.deleteRecord "$_username" "$_nsid_upload" "$key")"
    error="$(atfile.util.get_xrpc_error $? "$record")"
    
    if [[ -z "$error" ]]; then
        if [[ $_output_json == 1 ]]; then
            echo "{ \"deleted\": true }" | jq
        else
            echo "Deleted: $key"
        fi
    else
        atfile.die.xrpc_error "Unable to delete '$key'" "$error"
    fi
}

function atfile.invoke.download() {
    key="$1"
    decrypt=$2
    success=1
    downloaded_file=""
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
        blob_uri="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        file_name="$(echo "$record" | jq -r '.value.file.name')"
        key="$(atfile.util.get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        downloaded_file="$(atfile.util.build_out_filename "$key" "$file_name")"
        
        curl -H "User-Agent: $(atfile.util.get_uas)" --silent "$blob_uri" -o "$downloaded_file"
        [[ $? != 0 ]] && success=0
    fi
    
    if [[ $decrypt == 1 && $success == 1 ]]; then
        new_downloaded_file="$(echo $downloaded_file | sed -s s/.gpg//)"
        
        gpg --quiet --output "$new_downloaded_file" --decrypt "$downloaded_file"
        
        if [[ $? != 0 ]]; then
            success=0
        else
            rm -f "$downloaded_file"
            downloaded_file="$new_downloaded_file"
        fi
    fi
    
    if [[ $success == 1 ]]; then
        if [[ $_output_json == 1 ]]; then
            is_decrypted="false"
            [[ $decrypt == 1 ]] && is_decrypted="true"
            echo -e "{ \"decrypted\": $is_decrypted, \"name\": \"$(basename "${downloaded_file}")\", \"path\": \"$(atfile.util.get_realpath "${downloaded_file}")\" }" | jq
        else
            echo -e "Downloaded: $key"
            [[ $decrypt == 1 ]] && echo "Decrypted: $downloaded_file"
            echo -e "↳ Path: $(atfile.util.get_realpath "$downloaded_file")"
        fi
    else
        [[ -f "$downloaded_file" ]] && rm -f "$downloaded_file"
        atfile.die "Unable to download '$key'"
    fi
}

function atfile.invoke.get() {
    key="$1"
    success=1
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        did="$(echo $record | jq -r ".uri" | cut -d "/" -f 3)"
        key="$(atfile.util.get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        blob_uri="$(atfile.util.build_blob_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        cdn_uri="$(atfile.util.get_cdn_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")" "$file_type")"

        unset locked
        unset encrypted
        
        atfile.say.debug "Getting record...\n↳ NSID: $_nsid_lock\n↳ Repo: $_username\n↳ Key: $key"
        locked_record="$(com.atproto.repo.getRecord "$_username" "$_nsid_lock" "$key")"
        if [[ $? == 0 ]] && [[ -n "$locked_record" ]]; then
            if [[ $(echo $locked_record | jq -r ".value.lock") == true ]]; then
                locked="$(atfile.util.get_yn 1)"
            else
                locked="$(atfile.util.get_yn 0)"
            fi
        fi
        
        if [[ "$file_type" == "application/prs.atfile.gpg-crypt" ]]; then
            encrypted="$(atfile.util.get_yn 1)"
        else
            encrypted="$(atfile.util.get_yn 0)"
        fi
    
        if [[ $_output_json == 1 ]]; then
            browser_accessible=$(atfile.util.get_yn $(atfile.util.is_url_accessible_in_browser "$blob_uri"))
        
            echo "{ \"encrypted\": $encrypted, \"locked\": $locked, \"upload\": $(echo "$record" | jq -r ".value"), \"url\": { \"blob\": \"$blob_uri\", \"browser_accessible\": $browser_accessible, \"cdn\": { \"bsky\": \"$cdn_uri\" } } }" | jq
        else
            file_date="$(echo "$record" | jq -r '.value.file.modifiedAt')"
            file_hash="$(echo "$record" | jq -r '.value.checksum.hash')"
            file_hash_type="$(echo "$record" | jq -r '.value.checksum.algo')"
            [[ "$file_hash_type" == "null" ]] && file_hash_type="$(echo "$record" | jq -r '.value.checksum.type')"
            file_hash_pretty="$file_hash ($file_hash_type)"
            file_name="$(echo "$record" | jq -r '.value.file.name')"
            file_name_pretty="$(atfile.util.get_file_name_pretty "$(echo "$record" | jq -r '.value')")"
            file_size="$(echo "$record" | jq -r '.value.file.size')"
            file_size_pretty="$(atfile.util.get_file_size_pretty $file_size)"

            unset finger_type
            header="$file_name_pretty"
        
            if [[ $(atfile.util.is_null_or_empty "$file_hash_type") == 1 ]] || [[ "$file_hash_type" == "md5" && ${#file_hash} != 32 ]] || [[ "$file_hash_type" == "none" ]]; then
                file_hash_pretty="(None)"
            fi
        
            if [[ "$(echo $record | jq -r ".value.finger")" != "null" ]]; then
                finger_type="$(echo $record | jq -r ".value.finger.\"\$type\"" | cut -d "#" -f 2)"
            fi

            echo "$header"
            atfile.util.print_blob_url_output "$blob_uri"
            [[ -n "$cdn_uri" ]] && echo -e " ↳ CDN: $cdn_uri"
            echo -e "↳ URI: atfile://$_username/$key"
            echo -e "↳ File: $key"
            echo -e " ↳ Name: $file_name"
            echo -e " ↳ Type: $file_type"
            echo -e " ↳ Size: $file_size_pretty"
            echo -e " ↳ Date: $(atfile.util.get_date "$file_date" "%Y-%m-%d %H:%M:%S %Z")"
            echo -e " ↳ Hash: $file_hash_pretty"
            echo -e "↳ Locked: $locked"
            echo -e "↳ Encrypted: $encrypted"
            if [[ -z "$finger_type" ]]; then
                echo -e "↳ Source: (Unknown)"
            else
                case $finger_type in
                    "browser")
                        finger_browser_uas="$(echo $record | jq -r ".value.finger.userAgent")"

                        [[ -z $finger_browser_uas || $finger_browser_uas == "null" ]] && finger_browser_uas="(Unknown)"

                        echo -e "↳ Source: $finger_browser_uas"
                        ;;
                    "machine")
                        finger_machine_app="$(echo $record | jq -r ".value.finger.app")"
                        finger_machine_host="$(echo $record | jq -r ".value.finger.host")"
                        finger_machine_os="$(echo $record | jq -r ".value.finger.os")"

                        [[ -z $finger_machine_app || $finger_machine_app == "null" ]] && finger_machine_app="(Unknown)"

                        echo -e "↳ Source: $finger_machine_app"
                        [[ -n $finger_machine_host && $finger_machine_host != "null" ]] && echo -e " ↳ Host: $finger_machine_host"
                        [[ -n $finger_machine_os && $finger_machine_os != "null" ]] && echo -e " ↳ OS: $finger_machine_os"
                        ;;
                    *)
                        echo -e "↳ Source: (Unknown)"
                        ;;
                esac
            fi
        fi
    else
        atfile.die "Unable to get '$key'"
    fi
}

function atfile.invoke.get_url() {
    key="$1"
    unset error
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    error="$(atfile.util.get_xrpc_error $? "$record")"
    
    if [[ -z "$error" ]]; then
        blob_url="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"

        if [[ $_output_json == 1 ]]; then
            echo -e "{\"url\": \"$blob_url\" }" | jq
        else
            echo "$blob_url"
        fi
    else
        atfile.die.xrpc_error "Unable to get '$key'" "$error"
    fi
}

function atfile.invoke.handle_atfile() {
    uri="$1"
    handler="$2"

    function atfile.invoke.handle_atfile.is_temp_file_needed() {
        handler="$(echo $1 | sed s/.desktop$//g)"
        type="$2"

        handlers=(
            "app.drey.EarTag"
            "com.github.neithern.g4music"
        )

        if [[ ${handlers[@]} =~ $handler ]]; then
            echo 1
        elif [[ $type == "text/"* ]]; then
            echo 1
        else
            echo 0
        fi
    }

    [[ $_output_json == 1 ]] && atfile.die "Command not available as JSON"

    actor="$(echo $uri | cut -d "/" -f 3)"
    key="$(echo $uri | cut -d "/" -f 4)"

    if [[ -n "$actor" && -n "$key" ]]; then
        atfile.util.override_actor "$actor"
        atfile.util.print_override_actor_debug

        atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
        record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
        error="$(atfile.util.get_xrpc_error $? "$record")"
        [[ -n "$error" ]] && atfile.die.gui.xrpc_error "Unable to get '$key'" "$error"

        blob_cid="$(echo $record | jq -r ".value.blob.ref.\"\$link\"")"
        blob_uri="$(atfile.util.build_blob_uri "$_username" "$blob_cid")"
        file_type="$(echo $record | jq -r '.value.file.mimeType')"

        if [[ $_os == "linux"* ]] && \
            [ -x "$(command -v xdg-mime)" ] && \
            [ -x "$(command -v xdg-open)" ] && \
            [ -x "$(command -v gtk-launch)" ]; then

            [[ -z $file_type ]] && file_type="text/html" # HACK: Open with browser is file_type isn't set

            if [[ -z $handler ]]; then
                atfile.say.debug "Querying for handler '$file_type'..."
                handler="$(xdg-mime query default $file_type)"
            else
                handler="$handler.desktop"
                atfile.say.debug "Handler manually set to '$handler'"
            fi

            if [[ -n $handler ]] || [[ $? != 0 ]]; then
                atfile.say.debug "Opening '$key' ($file_type) with '$(echo $handler | sed s/.desktop$//g)'..."

                # HACK: Some apps don't like http(s)://; we'll need to handle these
                if [[ $(atfile.invoke.handle_atfile.is_temp_file_needed "$handler" "$file_type") == 1 ]]; then
                    atfile.say.debug "Unsupported for streaming"

                    download_success=1
                    tmp_path="$_path_blobs_tmp/$blob_cid"

                    if ! [[ -f "$tmp_path" ]]; then
                        atfile.say.debug "Downloading '$blob_cid'..."
                        atfile.http.download "$blob_uri" "$tmp_path"
                        [[ $? != 0 ]] && download_success=0
                    else
                        atfile.say.debug "Blob '$blob_cid' already exists"
                    fi

                    if [[ $download_success == 1 ]]; then
                        atfile.say.debug "Launching '$handler'..."
                        gtk-launch "$handler" "$tmp_path" </dev/null &>/dev/null &
                    else
                        atfile.die.gui \
                            "Unable to download '$key'"
                    fi
                else
                    atfile.say.debug "Launching '$handler'..."
                    gtk-launch "$handler" "$blob_uri" </dev/null &>/dev/null &
                fi
            else
                atfile.say.debug "No handler for '$file_type'. Launching URI..."
                atfile.util.launch_uri "$blob_uri"
            fi
        else
            atfile.say.debug "Relevant tools not installed. Launching URI..."
            atfile.util.launch_uri "$blob_uri"
        fi
    else
        atfile.die.gui \
            "Invalid ATFile URI\n↳ Must be 'atfile://<actor>/<key>'" \
            "Invalid ATFile URI"
    fi
}

function atfile.invoke.handle_aturi() {
    uri="$1"

    [[ $_output_json == 1 ]] && atfile.die "Command not available as JSON"
    [[ "$uri" != "at://"* ]] && atfile.die.gui \
        "Invalid AT URI\n↳ Must be 'at://<actor>[/<collection>/<rkey>]'" \
        "Invalid AT URI"

    atfile.say.debug "Resolving '$uri'..."
    app_uri="$(atfile.util.get_app_url_for_at_uri "$uri")"
    [[ -z "$app_uri" ]] && atfile.die.gui \
        "Unable to resolve AT URI to App"

    app_proto="$(echo $app_uri | cut -d ":" -f 1)"

    atfile.say.debug "Opening '$app_uri' ($app_proto)..."

    if [[ $app_proto == "atfile" ]]; then
        atfile.invoke.handle_atfile "$app_uri"
    else
        atfile.util.launch_uri "$app_uri"
    fi
}

function atfile.invoke.list() {
    cursor="$1"
    unset error
    
    atfile.say.debug "Getting records...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username"
    records="$(com.atproto.repo.listRecords "$_username" "$_nsid_upload" "$cursor")"
    error="$(atfile.util.get_xrpc_error $? "$records")"
   
    if [[ -z "$error" ]]; then
        records="$(echo $records | jq -c '.records[]')"
        if [[ -z "$records" ]]; then
            if [[ -n "$cursor" ]]; then
                atfile.die "No more files for '$_username'"
            else
                atfile.die "No files for '$_username'"
            fi
        fi
        
        unset last_key
        unset record_count
        unset json_output
            
        if [[ $_output_json == 0 ]]; then
            echo -e "Key\t\tFile"
            echo -e "---\t\t----"
        else
            json_output="{\"uploads\":["
        fi
        
        while IFS=$"\n" read -r c; do
            key=$(atfile.util.get_rkey_from_at_uri "$(echo $c | jq -r ".uri")")
            name="$(echo "$c" | jq -r '.value.file.name')"
            type_emoji="$(atfile.util.get_file_type_emoji "$(echo "$c" | jq -r '.value.file.mimeType')")"
            last_key="$key"
            ((record_count++))

            if [[ -n $key ]]; then
                if [[ $_output_json == 1 ]]; then
                    json_output+="$c,"
                else
                    if [[ $_os == "haiku" ]]; then
                        echo -e "$key\t$name" # BUG: Haiku Terminal has issues with emojis
                    else
                        echo -e "$key\t$type_emoji $name"
                    fi
                fi
            fi
        done <<< "$records"

        if [[ $_output_json == 0 ]]; then
            atfile.util.print_table_paginate_hint "$last_key" $record_count
        else
            json_output="${json_output::-1}"
            json_output+="],"
            json_output+="\"cursor\": \"$last_key\"}"
            echo -e "$json_output" | jq
        fi
    else
        atfile.die.xrpc_error "Unable to list files" "$error"
    fi
}

function atfile.invoke.lock() {
    key="$1"
    locked=$2
    unset error
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    upload_record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    error=$(atfile.util.get_xrpc_error $? "$upload_record")
    
    if [[ -z "$error" ]]; then        
        if [[ $locked == 1 ]]; then
            locked=true
        else
            locked=false
        fi
        
        lock_record="$(blue.zio.atfile.lock $locked)"
        
        atfile.say.debug "Updating record...\n↳ NSID: $_nsid_lock\n↳ Repo: $_username\n↳ Key: $key"
        record="$(com.atproto.repo.putRecord "$_username" "$_nsid_lock" "$key" "$lock_record")"
        error=$(atfile.util.get_xrpc_error $? "$record")
    fi
    
    if [[ -z "$error" ]]; then
        if [[ $_output_json == 1 ]]; then
            echo -e "{ \"locked\": $locked }" | jq
        else
            if [[ $locked == true ]]; then
                echo "Locked: $key"
            else
                echo "Unlocked: $key"
            fi
        fi
    else
        if [[ $locked == true ]]; then
            atfile.die "Unable to lock '$key'" "$error"
        else
            atfile.die "Unable to unlock '$key'" "$error"
        fi
    fi
}

function atfile.invoke.manage_record() {
    function atfile.invoke.manage_record.get_collection() {
        collection="$_nsid_upload"
        parameter_output="$1"
        [[ -n "$1" ]] && collection="$1" # fuck it, manage all the records from atfile!
        echo "$collection"
    }
    
    case "$1" in
        "create")
            collection="$(atfile.invoke.manage_record.get_collection "$3")"
            record="$2"
            [[ -z "$record" ]] && atfile.die "<record> not set"
            
            record_json="$(echo "$record" | jq)"
            [[ $? != 0 ]] && atfile.die "Invalid JSON"
            
            com.atproto.repo.createRecord "$_username" "$collection" "$record_json" | jq
            ;;
        "delete")
            collection="$(atfile.invoke.manage_record.get_collection "$3")"
            key="$2"
            [[ -z "$key" ]] && atfile.die "<key/at-uri> not set"
            
            if [[ "$key" == at:* ]]; then
                at_uri="$key"
                collection="$(echo $at_uri | cut -d "/" -f 4)"
                key="$(echo $at_uri | cut -d "/" -f 5)"
                username="$(echo $at_uri | cut -d "/" -f 3)"
                
                [[ "$username" != "$_username" ]] && atfile.die "Unable to delete record — not owned by you ($_username)"
            fi
            
            com.atproto.repo.deleteRecord "$_username" "$collection" "$key" | jq
            ;;
        "get")
            collection="$(atfile.invoke.manage_record.get_collection "$3")"
            key="$2"
            username="$4"
            [[ -z "$key" ]] && atfile.die "<key/at-uri> not set"
            
            if [[ "$key" == at:* ]]; then
                at_uri="$key"
                collection="$(echo $at_uri | cut -d "/" -f 4)"
                key="$(echo $at_uri | cut -d "/" -f 5)"
                username="$(echo $at_uri | cut -d "/" -f 3)"
            fi
            
            if [[ -z "$username" ]]; then
                username="$_username"
            else
                if [[ $username != $_username ]]; then
                    atfile.util.override_actor "$username"
                    atfile.util.print_override_actor_debug
                fi
            fi
            
            com.atproto.repo.getRecord "$username" "$collection" "$key" | jq
            atfile.util.override_actor_reset
            ;;
        "put") # BUG: Collection is always blue.zio.atfile.upload when not using at://
            collection="$(atfile.invoke.manage_record.get_collection "$4")"
            key="$2"
            record="$3"
            [[ -z "$key" ]] && atfile.die "<key/at-uri> not set"
            [[ -z "$record" ]] && atfile.die "<record> not set"
            
            record_json="$(echo "$record" | jq)"
            [[ $? != 0 ]] && atfile.die "Invalid JSON"
            
            if [[ "$key" == at:* ]]; then
                at_uri="$key"
                collection="$(echo $at_uri | cut -d "/" -f 4)"
                key="$(echo $at_uri | cut -d "/" -f 5)"
                username="$(echo $at_uri | cut -d "/" -f 3)"
                
                [[ "$username" != "$_username" ]] && atfile.die "Unable to put record — not owned by you ($_username)"
            fi
            
            com.atproto.repo.putRecord "$_username" "$collection" "$key" "$record" | jq
            ;;
    esac
}

function atfile.invoke.now() {
    date="$1"
    atfile.util.get_date "$1"
}

function atfile.invoke.print() {
    key="$1"
    unset error
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    error="$(atfile.util.get_xrpc_error $? "$record")"
    
    if [[ -z "$error" ]]; then
        blob_uri="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        
        curl -H "$(atfile.util.get_uas)" -s -L "$blob_uri" --output -
        [[ $? != 0 ]] && error="?"
    fi
    
    if [[ -n "$error" ]]; then
        atfile.die "Unable to cat '$key'" "$error"
    fi
}

function atfile.invoke.token() {
    atfile.xrpc.jwt
}

function atfile.invoke.toggle_desktop() {
    unset desktop_dir
    unset mime_dir

    [[ $_os == "haiku" ]] && atfile.die "Not available on Haiku"
    [[ $_os == "macos" ]] && atfile.die "Not available on macOS\nThink you could help? See: https://github.com/electricduck/atfile/issues/9"

    if [[ $uid == 0 ]]; then
        desktop_dir="/usr/local/share/applications"
        mime_dir="/usr/local/share/mime"
    else
        desktop_dir="$HOME/.local/share/applications"
        mime_dir="$HOME/.local/share/mime"
    fi

    desktop_path="$desktop_dir/atfile-handler.desktop"
    mkdir -p "$desktop_dir"
    mkdir -p "$mime_dir"

    if [[ -f "$desktop_path" ]]; then
        atfile.say "Removing '$desktop_path'..."
        rm "$desktop_path"
    else
        atfile.say "Installing '$desktop_path'..."

        echo "[Desktop Entry]
Name=ATFile (Handler)
Description=Handle atfile:/at: URIs with ATFile
Exec=$_prog_path handle %U
Terminal=false
Type=Application
MimeType=x-scheme-handler/at;x-scheme-handler/atfile;
NoDisplay=true" > "$desktop_path"
    fi

    if [ -x "$(command -v xdg-mime)" ] &&\
        [ -x "$(command -v update-mime-database)" ]; then
        atfile.say "Updating mime database..."

        update-mime-database "$mime_dir"
        xdg-mime default atfile-handler.desktop x-scheme-handler/at
        xdg-mime default atfile-handler.desktop x-scheme-handler/atfile
    fi
}

function atfile.invoke.upload() {
    file="$1"
    recipient="$2"
    key="$3"
    unset error
    
    if [[ ! -f "$file" ]]; then
        atfile.die "File '$file' does not exist"
    else
        file="$(atfile.util.get_realpath "$file")"
    fi

    if [[ $_output_json == 0 ]]; then
        if [[ "$_server" == *".host.bsky.network" ]]; then
            atfile.util.print_copyright_warning
        fi
    fi
    
    if [[ -n $recipient ]]; then
        file_crypt="$(dirname "$file")/$(basename "$file").gpg"
        
        [[ $_output_json == 0 ]] && echo -e "Encrypting '$file_crypt'..."
        gpg --yes --quiet --recipient $recipient --output "$file_crypt" --encrypt "$file"
        
        if [[ $? == 0 ]]; then
            file="$file_crypt"
        else
            rm -f "$file_crypt"
            atfile.die "Unable to encrypt '$(basename "$file")'"
        fi
    fi

    if [[ -z "$error" ]]; then
        unset file_date
        unset file_size
        unset file_type

        case "$_os" in
            "bsd-"*|"macos")
                file_date="$(atfile.util.get_date "$(stat -f '%Sm' -t "%Y-%m-%dT%H:%M:%SZ" "$file")")"
                file_size="$(stat -f '%z' "$file")"
                file_type="$(file -b --mime-type "$file")"
                ;;
            "haiku")
                haiku_file_attr="$(catattr BEOS:TYPE "$file" 2> /dev/null)"
                [[ $? == 0 ]] && file_type="$(echo "$haiku_file_attr" | cut -d ":" -f 3 | xargs)"

                file_date="$(atfile.util.get_date "$(stat -c '%y' "$file")")"
                file_size="$(stat -c %s "$file")"
                ;;
            *)
                file_date="$(atfile.util.get_date "$(stat -c '%y' "$file")")"
                file_size="$(stat -c %s "$file")"
                file_type="$(file -b --mime-type "$file")"
                ;;
        esac

        file_hash="$(atfile.util.get_md5 "$file")"
        file_hash_checksum="$(echo $file_hash | cut -d "|" -f 1)"
        file_hash_type="$(echo $file_hash | cut -d "|" -f 2)"
        file_name="$(basename "$file")"
        
        if [[ -n $recipient ]]; then
            file_type="application/prs.atfile.gpg-crypt"
        elif [[ "$file_type" == "application/"* ]]; then
            file_extension="$(echo "$file_name" | sed 's:.*\.::')"
            
            case "$file_extension" in
                "car") file_type="application/prs.atfile.car" ;;
                "dmg"|"smi") file_type="application/x-apple-diskimage" ;;
            esac
        fi
        
        file_type_emoji="$(atfile.util.get_file_type_emoji "$file_type")"

        atfile.say.debug "File: $file\n↳ Date: $file_date\n↳ Hash: $file_hash_checksum ($file_hash_type)\n↳ Name: $file_name\n↳ Size: $file_size\n↳ Type: $file_type_emoji $file_type"
        
        unset file_finger_record
        unset file_meta_record
        
        file_finger_record="$(atfile.util.get_finger_record)"
        file_meta_record="$(atfile.util.get_meta_record "$file" "$file_type")"

        atfile.say.debug "Checking filesize..."
        file_size_surplus="$(atfile.util.get_file_size_surplus_for_pds "$file_size" "$_server")"

        if [[ $file_size_surplus != 0 ]]; then
            die_message="File '$file_name' is too large ($(atfile.util.get_file_size_pretty $file_size_surplus) over)"
            atfile.die "$die_message"
        fi
        
        [[ $_output_json == 0 ]] && echo "Uploading '$file'..."
        
        blob="$(com.atproto.sync.uploadBlob "$file")"
        error="$(atfile.util.get_xrpc_error $? "$blob")"
        [[ $error == "?" ]] && error="Blob rejected by PDS (too large?)"

        atfile.say.debug "Uploading blob...\n↳ Ref: $(echo "$blob" | jq -r ".ref.\"\$link\"")"
    
        if [[ -z "$error" ]]; then
            file_record="$(blue.zio.atfile.upload "$blob" "$_now" "$file_hash_checksum" "$file_hash_type" "$file_date" "$file_name" "$file_size" "$file_type" "$file_meta_record" "$file_finger_record")"
            
            if [[ -n "$key" ]]; then
                atfile.say.debug "Updating record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
                record="$(com.atproto.repo.putRecord "$_username" "$_nsid_upload" "$key" "$file_record")"
                error="$(atfile.util.get_xrpc_error $? "$record")"
            else
                atfile.say.debug "Creating record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username"
                record="$(com.atproto.repo.createRecord "$_username" "$_nsid_upload" "$file_record")"
                error="$(atfile.util.get_xrpc_error $? "$record")"
            fi
        fi
    fi
    
    if [[ -n $recipient ]]; then
        rm -f "$file"
    fi

    if [[ -z "$error" ]]; then
        unset recipient_key
        blob_uri="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $blob | jq -r ".ref.\"\$link\"")")"
        key="$(atfile.util.get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        
        if [[ -n "$recipient" ]]; then
            recipient_key="$(gpg --list-keys $recipient | sed -n 2p | xargs)"
        fi

        if [[ $_output_json == 1 ]]; then
            unset recipient_json
        
            if [[ -n "$recipient" ]]; then
                recipient_json="{ \"id\": \"$recipient\", \"key\": \"$recipient_key\" }"
            else
                recipient_json="null"
            fi

            echo -e "{ \"blob\": \"$blob_uri\", \"key\": \"$key\", \"upload\": $record, \"recipient\": $recipient_json }" | jq
        else
            echo "---"
            if [[ $_os == "haiku" ]]; then
                echo "Uploaded: $file_name" # BUG: Haiku Terminal has issues with emojis
            else
                echo "Uploaded: $file_type_emoji $file_name"
            fi
            atfile.util.print_blob_url_output "$blob_uri"
            echo -e "↳ Key: $key"
            echo -e "↳ URI: atfile://$_username/$key"
            if [[ -n "$recipient" ]]; then
                echo -e "↳ Recipient: $recipient ($recipient_key)"
            fi
        fi
    else
        atfile.die.xrpc_error "Unable to upload '$file'" "$error"
    fi
}
