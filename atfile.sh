#!/usr/bin/env bash

_version="0.1.1"

# Utilities

function die() {
    echo -e "\033[1;31mError: $1\033[0m"
    exit 255
}

function check_prog() {
    command="$1"
    download_hint="$2"
    
    if ! [ -x "$(command -v $command)" ]; then
        message="'$command' not installed"
        
        if [[ -n "$download_hint" ]]; then
            message="$message (download: $download_hint)"
        fi
    
        die "$message"
    fi
}

function check_gpg_prog() {
    check_prog "gpg" "https://gnupg.org/download"
}

function get_blob_uri() {
    did="$1"
    blob_cid="$2"
    
    if [[ $_server == "https://zio.blue" ]]; then
        echo "$_server/blob/$did/$blob_cid"
    else
        echo "$_server/xrpc/com.atproto.sync.getBlob?cid=$blob_cid&did=$did"
    fi
}

function get_cdn_uri() {
    did="$1"
    blob_cid="$2"
    type="$3"
    
    cdn_uri=""
    
    case $type in
        "image/jpeg"|"image/png") cdn_uri="https://cdn.bsky.app/img/feed_thumbnail/plain/$did/$blob_cid@jpeg" ;;
    esac

    echo "$cdn_uri"
}

function get_date() {
    date="$1"
    
    if [[ -z "$date" ]]; then
        date -u +%Y-%m-%dT%H:%M:%SZ
    else
        date --date "$date" -u +%Y-%m-%dT%H:%M:%SZ
    fi
}

function get_envvar() {
    envvar="$1"
    default="$2"
    
    if [[ -z "${!envvar}" ]]; then
        echo $default
    else
        echo "${!envvar}"
    fi
}

function get_md5() {
    file="$1"
    md5sum "$file" | cut -f 1 -d " "
}

function get_rkey_from_at_uri() {
    at_uri="$1"
    echo $at_uri | cut -d "/" -f 5
}

function get_size_pretty() {
    size="$1"
    suffix=""
    
    if (( $size >= 1048576 )); then
        size=$(( $size / 1048576 ))
        suffix="MiB"
    elif (( $size >= 1024 )); then
        size=$(( $size / 1024 ))
        suffix="KiB"
    else
        suffix="Bytes"
    fi
    
    echo "$size $suffix"
}

function get_term_cols() {
    if [[ -n $COLUMNS ]]; then
        echo $COLUMNS
    else
        echo 80
    fi
}

function get_term_rows() {
    if [[ -n $LINES ]]; then
        echo $LINES
    else
        echo 40
    fi
}

function get_type_emoji() {
    mime_type="$1"
    short_type="$(echo $mime_type | cut -d "/" -f 1)"
    desc_type="$(echo $mime_type | cut -d "/" -f 2)"

    case $short_type in
        "application")
            case "$desc_type" in
                 # Apps (Desktop)
                "vnd.debian.binary-package"| \
                "vnd.microsoft.portable-executable"| \
                "x-executable"| \
                "x-rpm")
                    echo "💻" ;;
                # Apps (Mobile)
                "vnd.android.package-archive")
                    echo "📱" ;;
                # Archives
                "prs.atfile.car"| \
                "gzip"|"x-7z-compressed"|"x-bzip2"|"x-stuffit"|"x-xz"|"zip")
                    echo "📦" ;;
                # Disk Images
                "x-iso9660-image")
                    echo "💿" ;;
                # Encrypted
                "prs.atfile.gpg-crypt")
                    echo "🔑" ;;
                # Rich Text
                "pdf"| \
                "vnd.oasis.opendocument.text")
                    echo "📄" ;;
                *) echo "⚙️ " ;;
            esac
            ;;
        "audio") echo "🎵" ;;
        "font") echo "✏️" ;;
        "image") echo "🖼️ " ;;
        "text") 
            case "$mime_type" in
                "text/x-shellscript") echo "⚙️" ;;
                *) echo "📄" ;;
            esac
            ;;
        "video") echo "📼" ;;
        *) echo "❓" ;;
    esac
}

function is_xrpc_success() {
    exit_code="$1"
    data="$2"

    if [[ $exit_code != 0 || -z "$data" || "$data" == "{}" || "$data" == *"\"error\":"* ]]; then
        echo 0
    else
        echo 1
    fi
}

# HACK: This essentially breaks the entire session (it overrides $_username and
#       $_server) but where it's currently used should not cause any issues 🤞
function override_actor() {
    actor="$1"

    if [[ "$actor" != "did:"* ]]; then
        resolved_handle="$(com.atproto.identity.resolveHandle "$actor")"
        if [[ $(is_xrpc_success $? "$resolved_handle") == 1 ]]; then
            actor="$(echo "$resolved_handle" | jq -r ".did")"
        fi
    fi

    if [[ "$actor" == "did:"* ]]; then
        did_doc=""
        
        case "$actor" in
            "did:plc:"*) did_doc="$(curl -s -L -X GET "https://plc.directory/$actor")" ;; # TODO: What if they're not on plc.directory?
            "did:web:"*) did_doc="$(curl -s -L -X GET "$(echo "$actor" | sed "s/did:web://")/.well-known/did.json")" ;;
        esac
            
        if [[ $? != 0 || -z "$did_doc" ]]; then
            die "Unable to fetch DID Doc for '$actor'"
        else
            export _server="$(echo "$did_doc" | jq -r '.service[] | select(.id == "#atproto_pds") | .serviceEndpoint')"
            export _username="$(echo "$did_doc" | jq -r ".id")"
        fi
    else
        die "Unable to resolve '$actor'"
    fi
}

function repeat() {
    char="$1"
    amount="$2"
    
    printf "%0.s$char" $(seq 1 $amount)
}

function resolve_at_to_app() {
    at_uri="$1"
    
    did="$(echo $at_uri | cut -d "/" -f 3)"
    nsid="$(echo $at_uri | cut -d "/" -f 4)"
    rkey="$(echo $at_uri | cut -d "/" -f 5)"
    
    case $nsid in
        "app.bsky.feed.post") echo "https://bsky.app/profile/${did}/post/${rkey}" ;;
        *) echo "$at_uri" ;;
    esac
}

# XRPC

function xrpc_jwt() {
    curl -s -X POST $_server/xrpc/com.atproto.server.createSession \
        -H "Content-Type: application/json" \
        -H "User-Agent: ATFile/$_version" \
        -d '{"identifier": "'$_username'", "password": "'$_password'"}' | jq -r ".accessJwt"
}

function xrpc_get() {
    lexi="$1"
    query="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X GET $_server/xrpc/$lexi?$query \
        -H "Authorization: Bearer $(xrpc_jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: ATFile/$_version" \ | jq
}

function xrpc_post() {
    lexi="$1"
    data="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(xrpc_jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: ATFile/$_version" \
        -d "$data" | jq
}

function xrpc_post_blob() {
    file="$1"
    type="$2"
    lexi="$3"

    [[ -z $lexi ]] && lexi="com.atproto.repo.uploadBlob"
    [[ -z $type ]] && type="*/*"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(xrpc_jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: ATFile/$_version" \
        --data-binary @"$file" | jq
}

# Lexicons

function blue.zio.atfile.upload() {
    blob="$1"
    createdAt="$2"
    file_hash="$3"
    file_hash_type="$4"
    file_modifiedAt="$5"
    file_name="$6"
    file_size="$7"
    file_type="$8"

    echo "{
    \"createdAt\": \"$createdAt\",
    \"file\": {
        \"modifiedAt\": \"$file_modifiedAt\",
        \"mimeType\": \"$file_type\",
        \"name\": \"$file_name\",
        \"size\": $file_size
    },
    \"checksum\": {
        \"hash\": \"$file_hash\",
        \"type\": \"$file_hash_type\"
    },
    \"blob\": $blob
}"
}

function blue.zio.meta.profile() {
    nickname="$1"
    
    echo "{
    \"nickname\": \"$nickname\"  
}"
}

function app.bsky.actor.getProfile() {
    actor="$1"
    
    xrpc_get "app.bsky.actor.getProfile" "actor=$actor" 
}

function com.atproto.repo.createRecord() {
    repo="$1"
    collection="$2"
    record="$3"
    
    xrpc_post "com.atproto.repo.createRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"record\": $record }"
}

function com.atproto.repo.deleteRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"

    xrpc_post "com.atproto.repo.deleteRecord" "{ \"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\" }"
}

function com.atproto.repo.getRecord() {
    repo="$1"
    collection="$2"
    key="$3"

    xrpc_get "com.atproto.repo.getRecord" "repo=$repo&collection=$collection&rkey=$key"
}

function com.atproto.repo.listRecords() {
    repo="$1"
    collection="$2"
    cursor="$3"
    
    xrpc_get "com.atproto.repo.listRecords" "repo=$repo&collection=$collection&limit=$_max_list&cursor=$cursor"
}

function com.atproto.repo.putRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"
    record="$4"
    
    xrpc_post "com.atproto.repo.putRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\", \"record\": $record }"
}

function com.atproto.identity.resolveHandle() {
    handle="$1"

    xrpc_get "com.atproto.identity.resolveHandle" "handle=$handle"
}

function com.atproto.server.getSession() {
    xrpc_get "com.atproto.server.getSession"
}

function com.atproto.sync.listBlobs() {
    did="$1"
    cursor="$2"
    
    xrpc_get "com.atproto.sync.listBlobs" "did=$did&limit=$_max_list&cursor=$cursor"
}

function com.atproto.sync.uploadBlob() {
    file="$1"
    xrpc_post_blob "$1" | jq -r ".blob"
}

# Commands

function invoke_delete() {
    key="$1"
    success=1

    record="$(com.atproto.repo.deleteRecord "$_username" "blue.zio.atfile.upload" "$key")"
    
    if [[ $(is_xrpc_success $? "$record") == 1 ]]; then
        echo "Deleted: $key"
    else
        die "Unable to delete '$key'"
    fi
}

function invoke_download() {
    key="$1"
    out_dir="$2"
    decrypt=$3
    success=1
    downloaded_file=""
    
    if [[ -n "$out_dir" ]]; then
        mkdir -p "$out_dir"
        [[ $? != 0 ]] && die "Unable to create '$out_dir'"
        out_dir="$(realpath "$out_dir")/"
    fi
    
    record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
        blob_uri="$(get_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        file_name="$(echo "$record" | jq -r '.value.file.name')"
        key="$(get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        downloaded_file="${out_dir}${key}__${file_name}"
        
        curl --silent "$blob_uri" -o "$downloaded_file"
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
        echo -e "Downloaded: $key"
        [[ $decrypt == 1 ]] && echo "Decrypted: $downloaded_file"
        echo -e "↳ Path: $(realpath "$downloaded_file")"
    else
        [[ -f "$downloaded_file" ]] && rm -f "$downloaded_file"
        die "Unable to download '$key'"
    fi
}

function invoke_get() {
    key="$1"
    success=1
    
    record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
    	file_date="$(echo "$record" | jq -r '.value.file.modifiedAt')"
    	file_hash="$(echo "$record" | jq -r '.value.checksum.hash')"
    	file_hash_type="$(echo "$record" | jq -r '.value.checksum.type')"
        file_name="$(echo "$record" | jq -r '.value.file.name')"
        file_size="$(echo "$record" | jq -r '.value.file.size')"
        file_size_pretty="$(get_size_pretty $file_size)"
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        file_type_emoji="$(get_type_emoji "$file_type")"
        
        did="$(echo $record | jq -r ".uri" | cut -d "/" -f 3)"
        key="$(get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        blob_uri="$(get_blob_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        cdn_uri="$(get_cdn_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")" "$file_type")"
        
        header="$file_type_emoji $key"
        echo "$header"
        echo -e "↳ Blob: $blob_uri"
        [[ -n "$cdn_uri" ]] && echo -e " ↳ CDN: $cdn_uri"
        echo -e "↳ File"
        echo -e " ↳ Name: $file_name"
        echo -e " ↳ Type: $file_type"
        echo -e " ↳ Size: $file_size_pretty"
        echo -e " ↳ Date: $(date --date "$file_date" "+%Y-%m-%d %H:%M:%S %Z")"
        echo -e "↳ Hash: $file_hash ($file_hash_type)"
        echo -e "↳ URI:  $(echo $record | jq -r ".uri")"
    else
        die "Unable to get '$key'"
    fi
}

function invoke_get_url() {
    key="$1"
    success=1
    
    record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    
    if [[ $success == 1 ]]; then
        echo "$(get_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
    else
        die "Unable to get '$key'"
    fi
}

function invoke_list() {
    cursor="$1"
    success=1
    
    records="$(com.atproto.repo.listRecords "$_username" "blue.zio.atfile.upload" "$cursor")"
    success="$(is_xrpc_success $? "$records")"
    
    echo -e "Key\t\tFile"
    echo -e "---\t\t----"
   
    if [[ $success == 1 ]]; then
        echo $records | jq -c '.records[]' |
            while IFS=$"\n" read -r c; do
                key=$(get_rkey_from_at_uri "$(echo $c | jq -r ".uri")")
                name="$(echo "$c" | jq -r '.value.file.name')"
                type_emoji="$(get_type_emoji "$(echo "$c" | jq -r '.value.file.mimeType')")"

                echo -e "$key\t$type_emoji $name"
            done
    else
        die "Unable to list files"
    fi
}

function invoke_list_blobs() {
    cursor="$1"
    success=1
    
    blobs="$(com.atproto.sync.listBlobs "$_username" "$cursor")"
    success="$(is_xrpc_success $? "$blobs")"
    
    echo -e "CID"
    echo -e "---"
   
    if [[ $success == 1 ]]; then
        echo $blobs | jq -c '.cids[]' |
            while IFS=$"\n" read -r c; do
                echo $c | jq -r "."
            done
    else
        die "Unable to list blobs"
    fi
}

function invoke_post() {
    service="$1"
    key="$2"
    
    upload_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    [[ $(is_xrpc_success $? "$upload_record") != 1 ]] && die "Unable to get '$key'"
    
    blob="$(echo "$upload_record" | jq -r ".value.blob")"
    type="$(echo "$upload_record" | jq -r ".value.file.mimeType")"
    nsid=""
    
    case "$service" in
        "app.bsky")
            nsid="app.bsky.feed.post"
            embed=""
            facets="$4"
            text="$3"
    
            case "$type" in
                "image/jpeg"|"image/png")
                     embed="{ \"\$type\": \"app.bsky.embed.images\", \"images\": [ { \"alt\": \"\", \"image\": $blob }] }" ;;
                *) die "Cannot embed '$type' into '$nsid'"
            esac
            
        record="{ \"\$type\": \"app.bsky.feed.post\", \"createdAt\": \"$_now\", \"embed\": $embed, $([[ -n "$facets" ]] && echo "\"facets\": $facets,") \"text\": \"$text\" }"
        ;;
    esac
    
    if [[ -n "$nsid" && -n "$record" ]]; then
        created_record="$(com.atproto.repo.createRecord "$_username" "$nsid" "$record")"

        if [[ $(is_xrpc_success $? "$created_record") == 1 ]]; then
                uri="$(echo $created_record | jq -r ".uri")"
                app="$(resolve_at_to_app "$uri")"
        
        	echo -e "Posted: $(get_type_emoji "$type") $key"
        	echo -e "↳ App: $app"
        	echo -e "↳ URI: $uri"
        else
        	die "Unable to post '$type'"
        fi
    fi
}

function invoke_print() {
    key="$1"
    success=1
    
    record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
        blob_uri="$(get_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        
        if [[ $file_type == "text/"* ]]; then
             curl "$blob_uri"
             [[ $? != 0 ]] && success=0
        else
            if [ -x "$(command -v xdg-open)" ]; then
               xdg-open "$blob_uri"
            else
               die "Unable to open non-plain/text files"
            fi
        fi
    fi
    
    if [[ $success != 1 ]]; then
        die "Unable to cat '$key'"
    fi
}

function invoke_profile() {
    nick="$1"
    
    profile_record="$(blue.zio.meta.profile "$1")"
    record="$(com.atproto.repo.putRecord "$_username" "blue.zio.meta.profile" "self" "$profile_record")"
    
    # HACK: Renamed record to "blue.zio.meta.profile". Remove this in the future.
    dummy="$(com.atproto.repo.deleteRecord "$_username" "blue.zio.atfile.profile" "self")"
    
    if [[ $(is_xrpc_success $? "$record") == 1 ]]; then
        record="$(com.atproto.repo.getRecord "$_username" "blue.zio.meta.profile" "self")"
    
        echo "Updated profile"
        echo "↳ Nickname: $(echo "$record" | jq -r ".value.nickname")"
    else
        die "Unable to update profile"
    fi
}

function invoke_upload() {
    file="$1"
    recipient="$2"
    key="$3"
    success=1
    
    if [ ! -f "$file" ]; then
        die "File '$file' does not exist"
    else
        file="$(realpath "$file")"
    fi
    
    if [[ -n $recipient ]]; then
        file_crypt="$(dirname "$file")/$(basename "$file").gpg"
        gpg --yes --quiet --recipient $recipient --output "$file_crypt" --encrypt "$file"
        [[ $? != 0 ]] && success=0
        
        if [[ $success == 1 ]]; then
            echo "Encrypted: $(basename "$file")"
            echo "↳ Recipient: $recipient ($(gpg --list-keys $recipient | sed -n 2p | xargs))"
            file="$file_crypt"
        else
            rm -f "$file_crypt"
            die "Unable to encrypt '$(basename "$file")'"
        fi
    fi

    if [[ $success == 1 ]]; then
        file_date="$(get_date "$(stat -c '%y' "$file")")"
        file_hash="$(get_md5 "$file")"
        file_hash_type="md5"
        file_name="$(basename "$file")"
        file_size="$(wc -c "$file" | cut -d " " -f 1)"
        file_type="$(file -b --mime-type "$file")"
        
        if [[ -n $recipient ]]; then
            file_type="application/prs.atfile.gpg-crypt"
        elif [[ "$file_type" == "application/octet-stream" ]]; then
            file_extension="$(echo "$file_name" | sed 's:.*\.::')"
            
            case "$file_extension" in
                "car") file_type="application/prs.atfile.car"
            esac
        fi
        
        file_type_emoji="$(get_type_emoji "$file_type")"
        blob="$(com.atproto.sync.uploadBlob "$file")"
        success=$(is_xrpc_success $? "$blob")
        
        file_record="$(blue.zio.atfile.upload "$blob" "$_now" "$file_hash" "$file_hash_type" "$file_date" "$file_name" "$file_size" "$file_type")"
        
        if [[ -n "$key" ]]; then
            record="$(com.atproto.repo.putRecord "$_username" "blue.zio.atfile.upload" "$key" "$file_record")"
            success=$(is_xrpc_success $? "$record")
        else
            record="$(com.atproto.repo.createRecord "$_username" "blue.zio.atfile.upload" "$file_record")"
            success=$(is_xrpc_success $? "$record")
        fi
    fi
    
    if [[ -n $recipient ]]; then
        rm -f "$file"
    fi

    if [[ $success == 1 ]]; then
        echo "Uploaded: $file_type_emoji $file_name"
        echo -e "↳ Blob: $(get_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $blob | jq -r ".ref.\"\$link\"")")"
        echo -e "↳ Key:  $(get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
    else
        die "Unable to upload '$file'"
    fi
}

function invoke_usage() {
# ------------------------------------------------------------------------------
    echo -e "ATFile ($_prog) 📦➔🦋
    Store and retrieve files on a PDS
    
    Version $_version
    (c) 2024 Ducky <https://github.com/electricduck/atfile>
    Licensed under MIT License ✨
    
Commands
    upload <file> [<key>]
        Upload new file to the PDS
        ⚠️  ATProto records are public: do not upload sensitive files
        
    list [<cursor>] [<actor>]
        List all uploaded files. Only $_max_list items can be displayed; to
        paginate, use the last Key for <cursor>

    fetch <key> [<out-dir>] [<actor>]
        Download an uploaded file
        
    cat <key> [<actor>]
        Print (don't download) an uploaded file to the shell
        ℹ️  Only text/* files will print to the shell. Other files will open in
           a browser (using 'xdg-open'; if installed)
           
    url <key> [<actor>]
        Get blob URL for an uploaded file
        
    info <key> [<actor>]
        Get full details for an uploaded file

    delete <key>
        Delete an uploaded file
        ⚠️  This action is immediate and does not ask for confirmation!

    upload-crypt <file> <recipient> [<key>]
        Encrypt file (with GPG) for <recipient> and upload to the PDS
        ℹ️  Make sure the necessary GPG key has been imported first
        
    fetch-crypt <file> [<actor>]
        Download an uploaded encrypted file and attempt to decrypt it (with GPG)
        ℹ️  Make sure the necessary GPG key has been imported first
        
    post <key> [<bsky-text>] [<bsky-facets>]
        Post uploaded file to Bluesky
        
    nick <nick>
        Set nickname
        ℹ️  Intended for future use
       
Arguments
    <actor>     Act upon another ATProto user (either by handle or DID)
    <bsky-facets> ...
    <bsky-text> ...
    <cursor>    Key or CID used as a reference to paginate through lists
    <key>       Key of an uploaded file (unique to that user and collection)
    <nick>      Nickname
    <out-dir>   Path to receive downloaded files
    <recipient> GPG recipient during file encryption
                See 'gpg --help' for more information

Enviroment Variables
    ${_envvar_prefix}_PDS <string> (default: $_server_default)
        Endpoint of the PDS
    ${_envvar_prefix}_USERNAME <string>
        Username of the PDS user (handle or DID)
    ${_envvar_prefix}_PASSWORD <string>
        Password of the PDS user
        An App Password is recommended (https://bsky.app/settings/app-passwords)
    ${_envvar_prefix}_MAX_LIST <int> (default: $_max_list_default)
        Maximum amount of items in any lists
        Default value is calculated from your terminal's height
    ${_envvar_prefix}_SKIP_AUTH_CHECK <int> (default: $_skip_auth_check_default)
        Skip session validation on startup
        If you're confident your credentials are correct, and \$${_envvar_prefix}_USERNAME
        is a DID (*not* a handle), setting this to '1' will drastically improve
        performance!
"
# ------------------------------------------------------------------------------
}

# Main

_prog="$(basename "$(realpath -s "$0")")"
_now="$(get_date)"

_command="$1"

#_envvar_prefix="$(echo ${_prog^^} | cut -d "-" -f 1 | cut -d "." -f 1 | cut -d " " -f 1)"
_envvar_prefix="ATFILE"
_max_list_default=$(( $(get_term_rows) - 3 )) # NOTE: -3 accounting for the list header (2 lines) and the shell prompt (which is usually 1 line)
_server_default="https://bsky.social"
_skip_auth_check_default=0

_max_list="$(get_envvar "${_envvar_prefix}_MAX_LIST" "$_max_list_default")"
_server="$(get_envvar "${_envvar_prefix}_PDS" "$_server_default")"
_skip_auth_check="$(get_envvar "${_envvar_prefix}_SKIP_AUTH_CHECK" "$_skip_auth_check_default")"
_password="$(get_envvar "${_envvar_prefix}_PASSWORD")"
_username="$(get_envvar "${_envvar_prefix}_USERNAME")"

if [[ $_command == "help" || $_command == "h" || $_command == "--help" || $_command == "-h" ]]; then
    invoke_usage
    exit 0
fi

check_prog "curl"
check_prog "jq" "https://jqlang.github.io/jq"
check_prog "md5sum"
check_prog "xargs"

[[ -z "$_username" ]] && die "\$${_envvar_prefix}_USERNAME not set"
[[ -z "$_password" ]] && die "\$${_envvar_prefix}_PASSWORD not set"

if [[ $_skip_auth_check == 0 ]]; then
    session="$(com.atproto.server.getSession)"
    if [[ $(is_xrpc_success $? "$session") == 0 ]]; then
        die "Unable to authenticate as \"$_username\" on \"$_server\""
    else
        _username="$(echo $session | jq -r ".did")"
    fi
else
    if [[ "$_username" != "did:"* ]]; then
        die "Cannot skip authentication validation without a DID\n       ↳ \$${_envvar_prefix}_USERNAME currently set to '$_username' (need \"did:<type>:<key>\")"
    fi
fi

case "$_command" in
    "cat"|"open"|"print"|"c")
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$3" ]] && override_actor "$3"
        invoke_print "$2"
        ;;
    "delete"|"rm")
        [[ -z "$2" ]] && die "<key> not set"
        invoke_delete "$2"
        ;;
    "fetch"|"download"|"f"|"d")
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$4" ]] && override_actor "$4"
        invoke_download "$2" "$3"
        ;;
    "fetch-crypt"|"download-crypt"|"fc"|"dc")
        check_gpg_prog
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$4" ]] && override_actor "$4"
        invoke_download "$2" "$3" 1
        ;;
    "info"|"get"|"i")
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$3" ]] && override_actor "$3"
        invoke_get "$2"
        ;;
    "list"|"ls")
        [[ -n "$3" ]] && override_actor "$3"
        invoke_list "$2"
        ;;
    "list-blobs"|"lsb")
        invoke_list_blobs "$2"
        ;;
    "nick")
        invoke_profile "$2"
        ;;
    "post"|"bsky")
        [[ -z "$2" ]] && die "<key> not set"
        service="bsky" # NOTE: Futureproofing
        case service in
            "bsky"|"bluesky"|"app.bsky") invoke_post "app.bsky" "$2" "$3" "$4" ;;
            *) die "Service '$service' not supported" ;;
        esac
        ;;
    "upload"|"ul"|"u")
        [[ -z "$2" ]] && die "<file> not set"
        invoke_upload "$2" "" "$3"
        ;;
    "upload-crypt"|"uc")
        check_gpg_prog
        [[ -z "$2" ]] && die "<file> not set"
        [[ -z "$3" ]] && die "<recipient> not set"
        invoke_upload "$2" "$3" "$4"
        ;;
    "url"|"get-url"|"b")
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$3" ]] && override_actor "$3"
        invoke_get_url "$2"
        ;;
    *)
        die "Unknown command '$_command'; see 'help'"
        ;;
esac
