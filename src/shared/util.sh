#!/usr/bin/env bash

function atfile.util.build_blob_uri() {
    did="$1"
    cid="$2"
    pds="$_server"

    echo "$_fmt_blob_url" | sed -e "s|\[pds\]|$pds|g" -e "s|\[server\]|$pds|g"  -e "s|\[cid\]|$cid|g" -e "s|\[did\]|$did|g"
}

function atfile.util.build_out_filename() {
    key="$1"
    name="$2"

    echo "$_fmt_out_file" | sed -e "s|\[name\]|$name|g" -e "s|\[key\]|$key|g"
}

function atfile.util.check_prog() {
    command="$1"
    download_hint="$2"
    skip_hint="$3"
    
    if ! [ -x "$(command -v $command)" ]; then
        message="'$command' not installed"
        
        if [[ -n "$download_hint" ]]; then
            if [[ "$download_hint" == "http"* ]]; then
                message="$message (download: $download_hint)"
            else
                message="$message (install: \`$download_hint\`)"
            fi
        fi

        if [[ -n "$skip_hint" ]]; then
            message="$message\n↳ This is optional; set ${skip_hint}=1 to ignore"
        fi
    
        atfile.die "$message"
    fi
}

function atfile.util.check_prog_gpg() {
    atfile.util.check_prog "gpg" "https://gnupg.org/download"
}

function atfile.util.check_prog_optional_metadata() {
    [[ $_skip_ni_exiftool == 0 ]] && atfile.util.check_prog "exiftool" "https://exiftool.org" "${_envvar_prefix}_SKIP_NI_EXIFTOOL"
    [[ $_skip_ni_mediainfo == 0 ]] && atfile.util.check_prog "mediainfo" "https://mediaarea.net/en/MediaInfo" "${_envvar_prefix}_SKIP_NI_MEDIAINFO"
}

function atfile.util.create_dir() {
    dir="$1"

    if ! [[ -d $dir  ]]; then
        mkdir -p "$dir"
        [[ $? != 0 ]] && atfile.die "Unable to create directory '$dir'"
    fi
}

function atfile.util.fmt_int() {
    printf "%'d\n" "$1"
}

function atfile.util.get_app_url_for_at_uri() {
    uri="$1"

    actor="$(echo $uri | cut -d / -f 3)"
    collection="$(echo $uri | cut -d / -f 4)"
    rkey="$(echo $uri | cut -d / -f 5)"

    ignore_url_validation=0
    resolved_actor="$(atfile.util.resolve_identity "$actor")"
    error="$(atfile.util.get_xrpc_error $? "$resolved_actor")"
    [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$actor'" "$resolved_actor"

    unset actor_handle
    unset actor_pds
    unset resolved_url
    
    if [[ $? == 0 ]]; then
        actor="$(echo "$resolved_actor" | cut -d "|" -f 1)"
        actor_handle="$(echo "$resolved_actor" | cut -d "|" -f 3 | cut -d "/" -f 3)"
        actor_pds="$(echo "$resolved_actor" | cut -d "|" -f 2)"
    else
        unset actor
    fi

    [[ -z "$rkey" ]] && rkey="self"

    if [[ -n "$actor" && -n "$collection" && -n "$rkey" ]]; then
        case "$collection" in
            "app.bsky.actor.profile") resolved_url="https://bsky.app/profile/$actor" ;;
            "app.bsky.feed.generator") resolved_url="https://bsky.app/profile/$actor/feed/$rkey" ;;
            "app.bsky.graph.list") resolved_url="https://bsky.app/profile/$actor/lists/$rkey" ;;
            "app.bsky.graph.starterpack") resolved_url="https://bsky.app/starter-pack/$actor/$rkey" ;;
            "app.bsky.feed.post") resolved_url="https://bsky.app/profile/$actor/post/$rkey" ;;
            "blue.linkat.board") resolved_url="https://linkat.blue/$actor_handle" ;;
            "blue.zio.atfile.upload") ignore_url_validation=1 && resolved_url="atfile://$actor/$rkey" ;;
            "chat.bsky.actor.declaration") resolved_url="https://bsky.app/messages/settings" ;;
            "com.shinolabs.pinksea.oekaki") resolved_url="https://pinksea.art/$actor/oekaki/$rkey" ;;
            "com.whtwnd.blog.entry") resolved_url="https://whtwnd.com/$actor/$rkey" ;;
            "events.smokesignal.app.profile") resolved_url="https://smokesignal.events/$actor" ;;
            "events.smokesignal.calendar.event") resolved_url="https://smokesignal.events/$actor/$rkey" ;;
            "fyi.unravel.frontpage.post") resolved_url="https://frontpage.fyi/post/$actor/$rkey" ;;
            "link.pastesphere.snippet") resolved_url="https://pastesphere.link/user/$actor/snippet/$rkey" ;;
            "app.bsky.feed.like"| \
            "app.bsky.feed.postgate"| \
            "app.bsky.feed.repost"| \
            "app.bsky.feed.threadgate"| \
            "app.bsky.graph.follow"| \
            "app.bsky.graph.listblock"| \
            "app.bsky.graph.listitem"| \
            "events.smokesignal.calendar.rsvp"| \
            "fyi.unravel.frontpage.comment"| \
            "fyi.unravel.frontpage.vote")
                record="$(atfile.xrpc.get "com.atproto.repo.getRecord" "repo=$actor&collection=$collection&rkey=$rkey" "" "$actor_pds")"

                if [[ -z "$(atfile.util.get_xrpc_error $? "$record")" ]]; then
                    case "$collection" in
                        "app.bsky.feed.like")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.subject.uri')")" ;;
                        "app.bsky.feed.postgate")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.post')")" ;;
                        "app.bsky.feed.repost")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.subject.uri')")" ;;
                        "app.bsky.feed.threadgate")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.post')")" ;;
                        "app.bsky.graph.follow")
                            resolved_url="https://bsky.app/profile/$(echo "$record" | jq -r '.value.subject')" ;;
                        "app.bsky.graph.listblock")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.subject')")" ;;
                        "app.bsky.graph.listitem")
                            resolved_url="https://bsky.app/profile/$(echo "$record" | jq -r '.value.subject')" ;;
                        "events.smokesignal.calendar.rsvp")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.subject.uri')")" ;;
                        "fyi.unravel.frontpage.comment")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.post.uri')")/$actor/$rkey" ;;
                        "fyi.unravel.frontpage.vote")
                            resolved_url="$(atfile.util.get_app_url_for_at_uri "$(echo "$record" | jq -r '.value.subject.uri')")" ;;
                    esac
                fi
                ;;
        esac
    elif [[ -n "$actor" ]]; then
        resolved_url="https://pdsls.dev/at/$actor"
    fi

    if [[ -n "$resolved_url" && $ignore_url_validation == 0 ]]; then
        if [[ $(atfile.util.is_url_okay "$resolved_url") == 0 ]]; then
            unset resolved_url
        fi
    fi

    echo "$resolved_url"
}

function atfile.util.get_cache() {
    file="$_path_cache/$1"
    
    if [[ ! -f "$file" ]]; then
        touch "$file"
        [[ $? != 0 ]] && atfile.die "Unable to create cache file ($file)"
    fi
    
    echo -e "$(cat "$file")"
}

function atfile.util.get_cdn_uri() {
    did="$1"
    blob_cid="$2"
    type="$3"
    
    cdn_uri=""
    
    case $type in
        "image/jpeg"|"image/png") cdn_uri="https://cdn.bsky.app/img/feed_thumbnail/plain/$did/$blob_cid@jpeg" ;;
    esac

    echo "$cdn_uri"
}

# TODO: Support BusyBox's shit `date` command
#       `date -u +"$format" -s "1996-08-11 01:23:34"``
function atfile.util.get_date() {
    date="$1"
    format="$2"
    unset in_format

    [[ -z $format ]] && format="%Y-%m-%dT%H:%M:%SZ"

    if [[ $_os == "bsd-"* ]]; then
        if [[ $date =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{3}){0,1})Z$ ]]; then
            date="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
            in_format="%Y-%m-%d %H:%M:%S"
        fi
    fi
    
    [[ -z $in_format ]] && in_format="$format"

    if [[ -z "$date" ]]; then
        if [[ $_os == "linux-musl" || $_os == "solaris" ]]; then
            echo ""
        else
            date -u +$format
        fi
    else
        if [[ $_os == "linux-musl" || $_os == "solaris" ]]; then
            echo ""
        elif [[ $_os == "bsd-"* || $_os == "macos" ]]; then
            date -u -j -f "$in_format" "$date" +"$format"
        else
            date --date "$date" -u +"$format"
        fi
    fi
}

function atfile.util.get_date_json() {
    date="$1"
    parsed="$2"

    if [[ -z "$parsed" ]]; then
        if [[ -n "$date" ]]; then
            parsed_date="$(atfile.util.get_date "$date" 2> /dev/null)"
            [[ $? == 0 ]] && parsed="$parsed_date"
        fi
    fi

    if [[ -n "$parsed" ]]; then
        echo "\"$parsed\""
    else
        echo "null"
    fi
}

function atfile.util.get_didplc_doc() {
    actor="$1"

    function atfile.util.get_didplc_doc.request_doc() {
        endpoint="$1"
        actor="$2"

        curl -H "User-Agent: $(atfile.util.get_uas)" -s -L -X GET "$endpoint/$actor"
    }

    didplc_endpoint="$_endpoint_plc_directory"
    didplc_doc="$(atfile.util.get_didplc_doc.request_doc "$didplc_endpoint" "$actor")"

    if [[ "$didplc_doc" != "{"* ]]; then
        didplc_endpoint="$_endpoint_plc_directory_fallback"
        didplc_doc="$(atfile.util.get_didplc_doc.request_doc "$didplc_endpoint" "$actor")"
    fi

    echo "$(echo $didplc_doc | jq ". += {\"directory\": \"$didplc_endpoint\"}")"
}

function atfile.util.get_didweb_doc_url() {
    actor="$1"
    echo "https://$(echo "$actor" | sed "s/did:web://")/.well-known/did.json"
}

function atfile.util.get_envvar() {
    envvar="$1"
    default="$2"
    envvar_from_envfile="$(atfile.util.get_envvar_from_envfile "$envvar")"
    envvar_value=""
    
    if [[ -n "${!envvar}" ]]; then
        envvar_value="${!envvar}"
    elif [[ -n "$envvar_from_envfile" ]]; then
        envvar_value="$envvar_from_envfile"
    fi
    
    if [[ -z "$envvar_value" ]]; then
        envvar_value="$default"
    fi
    
    echo "$envvar_value"
}

function atfile.util.get_envvar_from_envfile() {
    variable="$1"
    atfile.util.get_var_from_file "$_path_envvar" "$variable"
}

function atfile.util.get_exiftool_field() {
    file="$1"
    tag="$2"
    default="$3"
    output=""
    
    exiftool_output="$(eval "exiftool -c \"%+.6f\" -s -T -$tag \"$file\"")"
    
    if [[ -n "$exiftool_output" ]]; then
        if [[ "$exiftool_output" == "-" ]]; then
            output="$default"
        else
            output="$exiftool_output"
        fi
    else
        output="$default"
    fi
    
    echo "$(echo "$output" | sed "s|\"|\\\\\"|g")"
}

function atfile.util.get_file_name_pretty() {
    file_record="$1"
    emoji="$(atfile.util.get_file_type_emoji "$(echo "$file_record" | jq -r '.file.mimeType')")"
    file_name_no_ext="$(echo "$file_record" | jq -r ".file.name" | cut -d "." -f 1)"
    output="$file_name_no_ext"
    
    meta_type="$(echo "$file_record" | jq -r ".meta.\"\$type\"")"
    
    if [[ -n "$meta_type" ]]; then
        case $meta_type in
            "$_nsid_meta#audio")
                album="$(echo "$file_record" | jq -r ".meta.tags.album")"
                album_artist="$(echo "$file_record" | jq -r ".meta.tags.album_artist")"
                date="$(echo "$file_record" | jq -r ".meta.tags.date")"
                disc="$(echo "$file_record" | jq -r ".meta.tags.disc.position")"
                title="$(echo "$file_record" | jq -r ".meta.tags.title")"
                track="$(echo "$file_record" | jq -r ".meta.tags.track.position")"
                
                [[ $(atfile.util.is_null_or_empty "$album") == 1 ]] && album="(Unknown Album)"
                [[ $(atfile.util.is_null_or_empty "$album_artist") == 1 ]] && album_artist="(Unknown Artist)"
                [[ $(atfile.util.is_null_or_empty "$disc") == 1 ]] && disc=0
                [[ $(atfile.util.is_null_or_empty "$title") == 1 ]] && title="$file_name_no_ext"
                [[ $(atfile.util.is_null_or_empty "$track") == 1 ]] && track=0
                
                output="$title\n   $album_artist — $album"
                [[ $(atfile.util.is_null_or_empty "$date") == 0 ]] && output+=" ($(atfile.util.get_date "$date" "%Y"))"
                [[ $disc != 0 || $track != 0 ]] && output+=" [$disc.$track]"
                ;;
            "$_nsid_meta#photo")
                date="$(echo "$file_record" | jq -r ".meta.date.create")"
                lat="$(echo "$file_record" | jq -r ".meta.gps.lat")"
                long="$(echo "$file_record" | jq -r ".meta.gps.long")"
                title="$(echo "$file_record" | jq -r ".meta.title")"
                
                [[ -z "$title" ]] && title="$file_name_no_ext"
                
                output="$title"
                
                if [[ $(atfile.util.is_null_or_empty "$lat") == 0 && $(atfile.util.is_null_or_empty "$long") == 0 ]]; then
                   output+="\n   $long $lat"
                   
                   if [[ $(atfile.util.is_null_or_empty "$date") == 0 ]]; then
                       output+=" — $($(atfile.util.get_date "$date"))"
                   fi
                fi
                ;;
            "$_nsid_meta#video")
                title="$(echo "$file_record" | jq -r ".meta.tags.title")"
                
                [[ $(atfile.util.is_null_or_empty "$title") == 1 ]] && title="$file_name_no_ext"
                
                output="$title"
                ;;
        esac
    fi
    
    # BUG: Haiku Terminal has issues with emojis
    if [[ $_os != "haiku" ]]; then
        output="$emoji $output"
    fi
    
    output_last_line="$(echo -e "$output" | tail -n1)"
    output_last_line_length="${#output_last_line}"
    
    echo -e "$output"
    echo -e "$(atfile.util.repeat_char "-" $output_last_line_length)"
}

function atfile.util.get_file_size_pretty() {
    size="$1"
    suffix=""
    
    if (( $size >= 1048576 )); then
        size=$(( $size / 1048576 ))
        suffix="MiB"
    elif (( $size >= 1024 )); then
        size=$(( $size / 1024 ))
        suffix="KiB"
    else
        suffix="B"
    fi
    
    echo "$size $suffix"
}

# NOTE: There is currently no API for getting the filesize limit on the server
function atfile.util.get_file_size_surplus_for_pds() {
    size="$1"
    pds="$2"

    unset max_filesize

    case $pds in
        *".host.bsky.network") max_filesize=52428800 ;;
    esac

    if [[ -z $max_filesize ]] || [[ $max_filesize == 0 ]] || (( $size < $max_filesize )); then
        echo 0
    else
        echo $(( $size - $max_filesize ))
    fi
}

function atfile.util.get_file_type_emoji() {
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
                "vnd.android.package-archive"| \
                "x-ios-app")
                    echo "📱" ;;
                # Archives
                "prs.atfile.car"| \
                "gzip"|"x-7z-compressed"|"x-apple-diskimage"|"x-bzip2"|"x-stuffit"|"x-xz"|"zip")
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
        "inode") echo "🔌" ;;
        "text") 
            case "$mime_type" in
                "text/x-shellscript") echo "⚙️ " ;;
                *) echo "📄" ;;
            esac
            ;;
        "video") echo "📼" ;;
        *) echo "❓" ;;
    esac
}

function atfile.util.get_int_suffix() {
    int="$1"
    singular="$2"
    plural="$3"

    [[ $int == 1 ]] && echo -e "$singular" || echo -e "$plural"
}

function atfile.util.get_finger_record() {
    fingerprint_override="$1"
    unset enable_fingerprint_original

    if [[ $fingerprint_override ]]; then
        enable_fingerprint_original="$_enable_fingerprint"
        _enable_fingerprint="$fingerprint_override"
    fi

    echo -e "$(blue.zio.atfile.finger__machine)"

    if [[ -n $enable_fingerprint_original ]]; then
        _enable_fingerprint="$enable_fingerprint_original"
    fi
}

function atfile.util.get_line() {
    input="$1"
    index=$(( $2 + 1 ))
    
    echo "$(echo -e "$input" | sed -n "$(( $index ))"p)"
}

function atfile.util.get_mediainfo_field() {
    file="$1"
    category="$2"
    field="$3"
    default="$4"
    output=""

    mediainfo_output="$(mediainfo --Inform="$category;%$field%\n" "$file")"

    if [[ -n "$mediainfo_output" ]]; then
        if [[ "$mediainfo_output" == "None" ]]; then
            output="$default"
        else
            output="$mediainfo_output"
        fi
    else
        output="$default"
    fi
    
    echo "$(echo "$output" | sed "s|\"|\\\\\"|g")"
}

function atfile.util.get_mediainfo_audio_json() {
    file="$1"

    bitRates=$(atfile.util.get_mediainfo_field "$file" "Audio" "BitRate" 0)
    bitRate_modes=$(atfile.util.get_mediainfo_field "$file" "Audio" "BitRate_Mode" "")
    channelss=$(atfile.util.get_mediainfo_field "$file" "Audio" "Channels" 0)
    compressions="$(atfile.util.get_mediainfo_field "$file" "Audio" "Compression_Mode" "")"
    durations=$(atfile.util.get_mediainfo_field "$file" "Audio" "Duration" 0)
    formats="$(atfile.util.get_mediainfo_field "$file" "Audio" "Format" "")"
    format_ids="$(atfile.util.get_mediainfo_field "$file" "Audio" "CodecID" "")"
    format_profiles="$(atfile.util.get_mediainfo_field "$file" "Audio" "Format_Profile" "")"
    samplings=$(atfile.util.get_mediainfo_field "$file" "Audio" "SamplingRate" 0)
    titles="$(atfile.util.get_mediainfo_field "$file" "Audio" "Title" "")"
    
    lines="$(echo "$bitrates" | wc -l)"
    output=""

    for ((i = 0 ; i < $lines ; i++ )); do
        lossy=true
        
        [[ \"$(atfile.util.get_line "$compressionss" $i)\" == "Lossless" ]] && lossy=false
    
        output+="{
    \"bitRate\": $(atfile.util.get_line "$bitRates" $i),
    \"channels\": $(atfile.util.get_line "$channelss" $i),
    \"duration\": $(atfile.util.get_line "$durations" $i),
    \"format\": {
        \"id\": \"$(atfile.util.get_line "$format_ids" $i)\",
        \"name\": \"$(atfile.util.get_line "$formats" $i)\",
        \"profile\": \"$(atfile.util.get_line "$format_profiles" $i)\"
    },
    \"mode\": \"$(atfile.util.get_line "$bitrate_modes" $i)\",
    \"lossy\": $lossy,
    \"sampling\": $(atfile.util.get_line "$samplings" $i),
    \"title\": \"$(atfile.util.get_line "$titles" $i)\"
},"
    done
    
    echo "${output::-1}"
}

function atfile.util.get_mediainfo_video_json() {
    file="$1"

    bitRates=$(atfile.util.get_mediainfo_field "$file" "Video" "BitRate" 0)
    dim_height=$(atfile.util.get_mediainfo_field "$file" "Video" "Height" 0)
    dim_width=$(atfile.util.get_mediainfo_field "$file" "Video" "Width" 0)
    durations=$(atfile.util.get_mediainfo_field "$file" "Video" "Duration" 0)
    formats="$(atfile.util.get_mediainfo_field "$file" "Video" "Format" "")"
    format_ids="$(atfile.util.get_mediainfo_field "$file" "Video" "CodecID" "")"
    format_profiles="$(atfile.util.get_mediainfo_field "$file" "Video" "Format_Profile" "")"
    frameRates="$(atfile.util.get_mediainfo_field "$file" "Video" "FrameRate" "")"
    frameRate_modes="$(atfile.util.get_mediainfo_field "$file" "Video" "FrameRate_Mode" "")"
    titles="$(atfile.util.get_mediainfo_field "$file" "Video" "Title" "")"
    
    lines="$(echo "$bitrates" | wc -l)"
    output=""

    for ((i = 0 ; i < $lines ; i++ )); do    
        output+="{
    \"bitRate\": $(atfile.util.get_line "$bitRates" $i),
    \"dimensions\": {
        \"height\": $dim_height,
        \"width\": $dim_width
    },
    \"duration\": $(atfile.util.get_line "$durations" $i),
    \"format\": {
        \"id\": \"$(atfile.util.get_line "$format_ids" $i)\",
        \"name\": \"$(atfile.util.get_line "$formats" $i)\",
        \"profile\": \"$(atfile.util.get_line "$format_profiles" $i)\"
    },
    \"frameRate\": $(atfile.util.get_line "$frameRates" $i),
    \"mode\": \"$(atfile.util.get_line "$frameRate_modes" $i)\",
    \"title\": \"$(atfile.util.get_line "$titles" $i)\"
},"
    done
    
    echo "${output::-1}"
}

function atfile.util.get_meta_record() {
    file="$1"
    type="$2"
    
    case "$type" in
        "audio/"*) blue.zio.atfile.meta__audio "$1" ;;
        "image/"*) blue.zio.atfile.meta__photo "$1" ;;
        "video/"*) blue.zio.atfile.meta__video "$1" ;;
        *) blue.zio.atfile.meta__unknown "" "$type" ;;
    esac
}

function atfile.util.get_md5() {
    file="$1"

    unset checksum
    type="none"
    
    if [ -x "$(command -v md5sum)" ]; then
        hash="$(md5sum "$file" | cut -f 1 -d " ")"
        if [[ ${#hash} == 32 ]]; then
            checksum="$hash"
            type="md5"
        fi
    fi

    echo "$checksum|$type"
}

function atfile.util.get_os() {
    os="$OSTYPE"

    case $os in
        # Linux
        "linux-gnu") echo "linux" ;;
        "cygwin"|"msys") echo "linux-mingw" ;;
        "linux-musl") echo "linux-musl" ;;
        "linux-android") echo "linux-termux" ;;
        # BSD
        "FreeBSD"*|"freebsd"*) echo "bsd-freebsd" ;;
        "netbsd"*) echo "bsd-netbsd" ;;
        "openbsd"*) echo "bsd-openbsd" ;;
        # Misc.
        "haiku") echo "haiku" ;;
        "darwin"*) echo "macos" ;;
        "solaris"*) echo "solaris" ;;
        # Unknown
        *) echo "unknown-$OSTYPE" ;;
    esac
}

function atfile.util.get_pds_pretty() {
    pds="$1"

    pds_host="$(atfile.util.get_uri_segment "$pds" host)"
    unset pds_name
    unset pds_emoji

    if [[ $pds_host == *".host.bsky.network" ]]; then
        bsky_host="$(echo $pds_host | cut -d "." -f 1)"
        bsky_region="$(echo $pds_host | cut -d "." -f 2)"

        pds_name="${bsky_host^} ($(atfile.util.get_region_pretty "$bsky_region"))"
        pds_emoji="🍄"
    elif [[ $pds_host == "atproto.brid.gy" ]]; then
        pds_name="Bridgy Fed"
        pds_emoji="🔀"
    else
        pds_oauth_url="$pds/oauth/authorize"
        pds_oauth_page="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -L -X GET "$pds_oauth_url")"
        pds_customization_data="$(echo $pds_oauth_page | sed -s s/.*_customizationData\"]=//g | sed -s s/\;document\.currentScript\.remove.*//g)"

        if [[ $pds_customization_data == "{"* ]]; then
            pds_name="$(echo $pds_customization_data | jq -r '.name')"
            pds_emoji="🟦"
        else
            pds_name="$pds_host"
        fi
    fi
                                # BUG: Haiku Terminal has issues with emojis
    if [[ -n "$pds_emoji" ]] && [[ $_os != "haiku" ]]; then
        echo "$pds_emoji $pds_name"
    else
        echo "$pds_name"
    fi
}

function atfile.util.get_realpath() {
    path="$1"

    if [[ $_os == "solaris" ]]; then
        # INVESTIGATE: Use this for every OS?
        [ -d "$path" ] && (
            cd_path= \cd "$1"
            /bin/pwd
        ) || (
            cd_path= \cd "$(dirname "$1")" &&
            printf "%s/%s\n" "$(/bin/pwd)" "$(basename $1)"
        )
    else
        realpath "$path"
    fi
}

function atfile.util.get_region_pretty() {
    region="$1"

    region_sub="$(echo $1 | cut -d "-" -f 2)"
    region="$(echo $1 | cut -d "-" -f 1)"

    echo "${region^^} ${region_sub^}"
}

function atfile.util.get_rkey_from_at_uri() {
    at_uri="$1"
    echo $at_uri | cut -d "/" -f 5
}

function atfile.util.get_seconds_since_start() {
    current="$(atfile.util.get_date "" "%s")"
    echo "$(( $current - $_start ))"
}

function atfile.util.get_term_cols() {
    unset rows
    
    if [ -x "$(command -v tput)" ]; then
        cols=$(tput cols)
    fi

    if [[ -n $cols ]]; then
        echo $cols
    else
        echo 80
    fi
}

function atfile.util.get_term_rows() {
    unset rows
    
    if [ -x "$(command -v tput)" ]; then
        rows=$(tput lines)
    fi

    if [[ -n $rows ]]; then
        echo $rows
    else
        echo 30
    fi
}

function atfile.util.get_var_from_file() {
    file="$1"

    if [[ -f "$file" ]]; then
        variable="$2"
        found_line="$(cat "$file" | grep "\b${variable}=")"
        
        if [[ -n "$found_line" ]] && [[ ! "$found_line" == \#* ]]; then
            output="$(echo $found_line | sed "s|${variable}=||g")"
            output="${output%\"}"
            output="${output#\"}"

            if [[ $output == *"\$("* && $output == *")"* ]]; then
                eval "echo \"$output\""
            else
                echo "$output"
            fi
        fi
    fi
}

function atfile.util.get_uas() {
    echo "ATFile/$_version"
}

function atfile.util.get_xrpc_error() {
    exit_code="$1"
    data="$2"

    if [[ $exit_code != 0 || -z "$data" || "$data" == "null" || "$data" == "{}" || "$data" == *"\"error\":"* ]]; then
        if [[ "$data" == "{"* && "$data" == *"\"error\":"* ]]; then
            error="$(echo "$data" | jq -r ".error")"
            message="$(echo "$data" | jq -r ".message")"

            if [[ -z $message ]]; then
                echo "$error"
            else
                echo "[$error] $message"
            fi
        else
            echo "?"
        fi
    else
        echo ""
    fi
}

function atfile.util.get_yn() {
    yn="$1"
    
    if [[ $_output_json == 0 ]]; then
        if [[ $yn == 0 ]]; then
            echo "No"
        else
            echo "Yes"
        fi
    else
        if [[ $yn == 0 ]]; then
            echo "false"
        else
            echo "true"
        fi 
    fi
}

function atfile.util.is_null_or_empty() {
    if [[ -z "$1" ]] || [[ "$1" == null ]]; then
        echo 1
    else
        echo 0
    fi
}

function atfile.util.is_url_accessible_in_browser() {
    url="$1"
    atfile.util.is_url_okay "$url" "$_test_desktop_uas"
}

function atfile.util.is_url_okay() {
    url="$1"
    uas="$2"

    [[ -z "$uas" ]] && uas="$(atfile.util.get_uas)"

    code="$(curl -H "User-Agent: $uas" -s -o /dev/null -w "%{http_code}" "$url")"

    if [[ "$code" == 2* || "$code" == 3* ]]; then
        echo 1
    else
        echo 0
    fi
}

function atfile.util.launch_uri() {
    uri="$1"

    if [[ -n $DISPLAY ]] && [ -x "$(command -v xdg-open)" ]; then
        xdg-open "$uri"
    else
        case $_os in
            "haiku") open "$uri" ;;
            "macos") open "$uri" ;;
            *) echo "$uri"
        esac
    fi
}

function atfile.util.get_uri_segment() {
    uri="$1"
    segment="$2"
    unset parsed_uri

    case $segment in
        "host") echo $uri | cut -d "/" -f 3 ;;
        "protocol") echo $uri | cut -d ":" -f 1 ;;
        *) echo $uri | cut -d "/" -f $segment ;;
    esac
}

function atfile.util.map_http_to_at() {
    http_uri="$1"
    unset at_uri
    unset actor
    unset collection
    unset rkey

    case "$(atfile.util.get_uri_segment $http_uri host)" in
        "atproto-browser.vercel.app"|\
        "pdsls.dev"|\
        "pdsls.pages.dev")
            actor="$(atfile.util.get_uri_segment $http_uri 5)"
            collection="$(atfile.util.get_uri_segment $http_uri 6)"
            rkey="$(atfile.util.get_uri_segment $http_uri 7)"
            ;;
    esac

    if [[ -n "$actor" ]]; then
        at_uri="at://$actor"

        if [[ -n "$collection" ]]; then
            at_uri="$at_uri/$collection"

            if [[ -n "$rkey" ]]; then
                at_uri="$at_uri/$rkey"
            fi
        fi
    fi

    echo $at_uri
}

# HACK: This essentially breaks the entire session (it overrides $_username and
#       $_server). If sourcing, use atfile.util.override_actor_reset() to
#       reset
function atfile.util.override_actor() {
    actor="$1"
    
    [[ -z "$_server_original" ]] && _server_original="$_server"
    [[ -z "$_username_original" ]] && _username_original="$_username"
    [[ -z "$_fmt_blob_url_original" ]] && _fmt_blob_url_original="$fmt_blob_url"
    
    resolved_did="$(atfile.util.resolve_identity "$actor")"
    error="$(atfile.util.get_xrpc_error $? "$resolved_did")"
    [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$actor'" "$resolved_did"

    _username="$(echo $resolved_did | cut -d "|" -f 1)"
    _server="$(echo $resolved_did | cut -d "|" -f 2)"

    if [[ "$_fmt_blob_url" != "$_fmt_blob_url_default" ]]; then
        export _fmt_blob_url="$_fmt_blob_url_default"
    fi
}

# NOTE: This is to help during sourcing if atfile.uitl.override_actor() has
#       been called
function atfile.util.override_actor_reset() {
    [[ -n "$_server_original" ]] && _server="$_server_original"; unset _server_original
    [[ -n "$_username_original" ]] && _username="$_username_original"; unset _username_original
    [[ -n "$_fmt_blob_url_original" ]] && _fmt_blob_url="$_fmt_blob_url_original"; unset _fmt_blob_url_original
}

function atfile.util.parse_exiftool_date() {
    in_date="$1"
    tz="$2"
        
    date="$(echo "$in_date" | cut -d " " -f 1 | sed -e "s|:|-|g")"
    time="$(echo "$in_date" | cut -d " " -f 2)"
      
    echo "$date $time $tz"
}

function atfile.util.parse_version() {
    version="$1"
    version="$(echo $version | cut -d "+" -f 1)"
    v_major="$(printf "%04d\n" "$(echo $version | cut -d "." -f 1)")"
    v_minor="$(printf "%04d\n" "$(echo $version | cut -d "." -f 2)")"
    v_rev="$(printf "%04d\n" "$(echo $version | cut -d "." -f 3)")"
    echo "$(echo ${v_major}${v_minor}${v_rev} | sed 's/^0*//')"
}

function atfile.util.print_blob_url_output() {
    blob_uri="$1"
    
    run_cmd="$_prog url $key"
    [[ -n "$_username_original" ]] && run_cmd+=" $_username"
   
    if [[ $(atfile.util.is_url_accessible_in_browser "$blob_uri") == 0 ]]; then
        echo -e "↳ Blob: ⚠️  Blob cannot be viewed in a browser\n           Run '$run_cmd' to get URL"
    else
        echo -e "↳ Blob: $blob_uri"
    fi
}

function atfile.util.print_copyright_warning() {
    if [[ $_skip_copyright_warn == 0 ]]; then
        echo "
  ##########################################
  # You are uploading files to Bluesky PDS #
  #    Do not upload copyrighted files!    #
  ##########################################
"
    fi
}

# HACK: We don't normally atfile.say() in the atfile.util.* namespace, but
#       atfile.until.override_actor() is in this namespace and it would be nice
#       to have a debug output for it when called in the main command case
function atfile.util.print_override_actor_debug() {
    atfile.say.debug "Overridden identity\n↳ DID: $_username\n↳ PDS: $_server\n↳ Blob URL: $_fmt_blob_url"
}

function atfile.util.print_seconds_since_start_debug() {
    seconds=$(atfile.util.get_seconds_since_start)
    second_unit="$(atfile.util.get_int_suffix $seconds "second" "seconds")"

    atfile.say.debug "$seconds $second_unit since start"
}

function atfile.util.print_table_paginate_hint() {
    cursor="$1"
    count="$2"
    
    if [[ -z $count ]] || (( ( $record_count + $_max_list_buffer ) >= $_max_list )); then
        first_line="List is limited to $_max_list results. To print more results,"
        first_line_length=$(( ${#first_line} + 3 ))
        echo -e "$(atfile.util.repeat_char "-" $first_line_length)\nℹ️  $first_line\n   run \`$_prog $_command $cursor\`"
    fi
}

function atfile.util.repeat_char() {
    char="$1"
    amount="$2"
    
    if [ -x "$(command -v seq)" ]; then
        printf "%0.s$char" $(seq 1 $amount)
    else
        echo "$char"
    fi
}

function atfile.util.resolve_identity() {
    actor="$1"
    
    if [[ "$actor" != "did:"* ]]; then
        resolved_handle="$(bsky.xrpc.get "com.atproto.identity.resolveHandle" "handle=$actor" "" "$_endpoint_resolve_handle")"
        error="$(atfile.util.get_xrpc_error $? "$resolved_handle")"

        if [[ -z "$error" ]]; then
            actor="$(echo "$resolved_handle" | jq -r ".did")"
        fi
    fi
    
    if [[ "$actor" == "did:"* ]]; then
        unset did_doc

        case "$actor" in
            "did:plc:"*) did_doc="$(atfile.util.get_didplc_doc "$actor")" ;;
            "did:web:"*) did_doc="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -L -X GET "$(atfile.util.get_didweb_doc_url "$actor")")" ;;
            *) echo "Unknown DID type 'did:$(echo "$actor" | cut -d ":" -f 2)'"; exit 255;;
        esac

        if [[ -n "$did_doc" ]]; then
            did="$(echo "$did_doc" | jq -r ".id")"

            if [[ $(atfile.util.is_null_or_empty "$did") == 1 ]]; then
                echo "$error"
                exit 255
            fi 

            unset aliases
            unset handle
            didplc_dir="$(echo "$did_doc" | jq -r ".directory")"
            pds="$(echo "$did_doc" | jq -r '.service[] | select(.id == "#atproto_pds") | .serviceEndpoint')"

            while IFS=$"\n" read -r a; do
                aliases+="$a;"

                if [[ -z $handle && "$a" == "at://"* && "$a" != "at://did:"* ]]; then
                    handle="$a"
                fi
            done <<< "$(echo "$did_doc" | jq -r '.alsoKnownAs[]')"

            [[ $didplc_dir == "null" ]] && unset didplc_dir
            [[ -z "$handle" ]] && handle="invalid.handle"
            
            echo "$did|$pds|$handle|$didplc_dir|$aliases"
        fi
    else
        echo "$error"
        exit 255
    fi
}

function atfile.util.write_cache() {
    file="$1"
    file_path="$_path_cache/$1"
    content="$2"
    
    atfile.util.get_cache "$file"
  
    echo -e "$content" > "$file_path"
    [[ $? != 0 ]] && atfile.die "Unable to write to cache file ($file)"
}
