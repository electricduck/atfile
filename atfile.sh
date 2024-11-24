#!/usr/bin/env bash

# ATFile <https://github.com/electricduck/atfile>
# Psst! You can 'source ./atfile.sh' in your own Bash scripts!

# Die

function atfile.die() {
    message="$1"
    
    if [[ $_output_json == 0 ]]; then
        atfile.say.die "$message"
    else
        echo -e "{ \"error\": \"$1\" }" | jq
    fi
    
    [[ $_is_sourced == 0 ]] && exit 255
}

function atfile.die.gui() {
    cli_error="$1"
    gui_error="$2"

    [[ -z $gui_error ]] && gui_error="$cli_error"

    if [ -x "$(command -v zenity)" ] && [[ $_is_sourced == 0 ]]; then
        zenity --error --text "$gui_error"
    fi

    atfile.die "$cli_error"
}

function atfile.die.unknown_command() {
    command="$1"
    atfile.die "Unknown command '$1'"
}

# Say

function atfile.say() {
    message="$1"
    prefix="$2"
    color_prefix="$3"
    color_message="$4"
    color_prefix_message="$5"
    suffix="$6"
    
    prefix_length=0
    
    [[ -z $color_prefix_message ]] && color_prefix_message=0
    [[ -z $suffix ]] && suffix="\n"
    [[ $suffix == "\\" ]] && suffix=""
    
    if [[ -z $color_message ]]; then
        color_message="\033[0m"
    else
        color_message="\033[${color_prefix_message};${color_message}m"
    fi
    
    if [[ -z $color_prefix ]]; then
        color_prefix="\033[0m"
    else
        color_prefix="\033[1;${color_prefix}m"
    fi
    
    if [[ -n $prefix ]]; then
        prefix_length=$(( ${#prefix} + 2 ))
        prefix="${color_prefix}${prefix}: \033[0m"
    fi
    
    message="$(echo "$message" | sed -e "s|\\\n|\\\n$(atfile.util.repeat_char " " $prefix_length)|g")"
    
    echo -n -e "${prefix}${color_message}$message\033[0m${suffix}"
}

function atfile.say.debug() {
    message="$1"

    if [[ $_debug == 1 ]]; then
        atfile.say "$message" "Debug" 35
    fi
}

function atfile.say.die() {
    message="$1"
    atfile.say "$message" "Error" 31 31 1
}

function atfile.say.inline() {
    message="$1"
    color="$2"
    atfile.say "$message" "" "" $color "" "\\"
}

# Utilities

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
    [[ $_skip_ni_exiftool == 0 ]] && atfile.util.check_prog "exiftool" "https://exiftool.org/" "${_envvar_prefix}_SKIP_NI_EXIFTOOL"
    [[ $_skip_ni_mediainfo == 0 ]] && atfile.util.check_prog "mediainfo" "https://mediaarea.net/en/MediaInfo" "${_envvar_prefix}_SKIP_NI_MEDIAINFO"
}

function atfile.util.create_dir() {
    dir="$1"

    if ! [[ -d $dir  ]]; then
        mkdir -p "$dir"
        [[ $? != 0 ]] && atfile.die "Unable to create directory '$dir'"
    fi
}

function atfile.util.get_app_url_for_at_uri() {
    uri="$1"

    actor="$(echo $uri | cut -d / -f 3)"
    collection="$(echo $uri | cut -d / -f 4)"
    rkey="$(echo $uri | cut -d / -f 5)"

    ignore_url_validation=0
    resolved_actor="$(atfile.util.resolve_identity "$actor")"
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
            "blue.linkat.board") ignore_url_validation=1 && resolved_url="https://linkat.blue/$actor_handle" ;;
            "blue.zio.atfile.upload") ignore_url_validation=1 && resolved_url="atfile://$actor/$rkey" ;;
            "chat.bsky.actor.declaration") resolved_url="https://bsky.app/messages/settings" ;;
            "com.shinolabs.pinksea.oekaki") resolved_url="https://pinksea.art/$actor/oekaki/$rkey" ;;
            "com.whtwnd.blog.entry") resolved_url="https://whtwnd.com/$actor/$rkey" ;;
            "events.smokesignal.app.profile") resolved_url="https://smokesignal.events/$actor" ;;
            "events.smokesignal.calendar.event") resolved_url="https://smokesignal.events/$actor/$rkey" ;;
            "fyi.unravel.frontpage.post") resolved_url="https://frontpage.fyi/post/$actor/$rkey" ;;
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

                if [[ "$(atfile.util.is_xrpc_success $? "$record")" == 1 ]]; then
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
    file="$_dir_cache/$1"
    
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

function atfile.util.get_date() {
    date="$1"
    format="$2"

    [[ -z $format ]] && format="%Y-%m-%dT%H:%M:%SZ"
    
    if [[ -z "$date" ]]; then
        date -u +$format
    else
        if [[ $_os == "macos" ]]; then
            date -u -j -f "$format" "$date" +"$format"
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

function atfile.util.get_file_path() {
    file="$1"
    
    if [ -f "$file" ]; then
        echo "$(realpath "$file")"
    fi
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

function atfile.util.get_finger_record() {
    echo -e "$(blue.zio.atfile.finger__machine)"
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
    
    hash="$(md5sum "$file" | cut -f 1 -d " ")"
    if [[ ${#hash} == 32 ]]; then
        echo "$hash"
    fi
}

function atfile.util.get_os() {
    case $OSTYPE in
        "darwin"*) echo "macos" ;;
        "haiku") echo "haiku" ;;
        "linux-gnu") echo "linux" ;;
        *) echo "unknown-$OSTYPE" ;;
    esac
}

function atfile.util.get_pds_pretty() {
    pds="$1"

    pds_host="$(echo $pds | cut -d "/" -f 3)"

    if [[ $pds_host == *".host.bsky.network" ]]; then
        bsky_host="$(echo $pds_host | cut -d "." -f 1)"
        bsky_region="$(echo $pds_host | cut -d "." -f 2)"
        echo "🍄 ${bsky_host^} ($(atfile.util.get_region_pretty "$bsky_region"))"
    elif [[ $pds_host == "atproto.brid.gy" ]]; then
        echo "🔀 Bridy Fed"
    else
        pds_oauth_url="$pds/oauth/authorize"
        pds_oauth_page="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -L -X GET "$pds_oauth_url")"
        pds_customization_data="$(echo $pds_oauth_page | sed -s s/.*_customizationData\"]=//g | sed -s s/\;document\.currentScript\.remove.*//g)"

        if [[ $pds_customization_data == "{"* ]]; then
            echo "🟦 $(echo $pds_customization_data | jq -r '.name')"
        else
            echo "$pds"
        fi
    fi
}

function atfile.util.get_realpath() {
    path="$1"

    if [[ $_os == "macos" ]]; then
        realpath "$path"
    else
        realpath -s "$path"
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

function atfile.util.is_xrpc_success() {
    exit_code="$1"
    data="$2"

    if [[ $exit_code != 0 || -z "$data" || "$data" == "null" || "$data" == "{}" || "$data" == *"\"error\":"* ]]; then
        echo 0
    else
        echo 1
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
    
    resolved_id="$(atfile.util.resolve_identity "$actor")"
    _username="$(echo $resolved_id | cut -d "|" -f 1)"
    _server="$(echo $resolved_id | cut -d "|" -f 2)"

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
    
    printf "%0.s$char" $(seq 1 $amount)
}

function atfile.util.resolve_identity() {
    actor="$1"
    
    if [[ "$actor" != "did:"* ]]; then
        resolved_handle="$(atfile.xrpc.get "com.atproto.identity.resolveHandle" "handle=$actor" "" "$_endpoint_resolve_handle")"
        if [[ $(atfile.util.is_xrpc_success $? "$resolved_handle") == 1 ]]; then
            actor="$(echo "$resolved_handle" | jq -r ".did")"
        fi
    fi
    
    if [[ "$actor" == "did:"* ]]; then
        unset did_doc
        
        case "$actor" in
            "did:plc:"*) did_doc="$(atfile.util.get_didplc_doc "$actor")" ;;
            "did:web:"*) did_doc="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -L -X GET "$(atfile.util.get_didweb_doc_url "$actor")")" ;;
        esac
            
        if [[ $? != 0 || -z "$did_doc" ]]; then
            atfile.die "Unable to fetch DID Doc for '$actor'"
        else
            did="$(echo "$did_doc" | jq -r ".id")"
            didplc_dir="$(echo "$did_doc" | jq -r ".directory")"
            pds="$(echo "$did_doc" | jq -r '.service[] | select(.id == "#atproto_pds") | .serviceEndpoint')"
            handle="$(echo "$did_doc" | jq -r '.alsoKnownAs[0]')"

            [[ $didplc_dir == "null" ]] && unset didplc_dir
            
            echo "$did|$pds|$handle|$didplc_dir"
        fi
    else
        atfile.die "Unable to resolve '$actor'"
    fi
}

function atfile.util.write_cache() {
    file="$1"
    file_path="$_dir_cache/$1"
    content="$2"
    
    atfile.util.get_cache "$file"
  
    echo -e "$content" > "$file_path"
    [[ $? != 0 ]] && atfile.die "Unable to write to cache file ($file)"
}

# HTTP

function atfile.http.download() {
    uri="$1"
    out_path="$2"

    curl -s -X GET "$uri" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -o "$out_path"
}

# XRPC

function atfile.xrpc.jwt() {
    curl -s -X POST $_server/xrpc/com.atproto.server.createSession \
        -H "Content-Type: application/json" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -d '{"identifier": "'$_username'", "password": "'$_password'"}' | jq -r ".accessJwt"
}

function atfile.xrpc.get() {
    lexi="$1"
    query="$2"
    type="$3"
    endpoint="$4"

    [[ -z $type ]] && type="application/json"
    [[ -z $endpoint ]] && endpoint="$_server"

    curl -s -X GET $endpoint/xrpc/$lexi?$query \
        -H "Authorization: Bearer $(atfile.xrpc.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \ | jq
}

function atfile.xrpc.post() {
    lexi="$1"
    data="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(atfile.xrpc.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        -d "$data" | jq
}

function atfile.xrpc.post_blob() {
    file="$1"
    type="$2"
    lexi="$3"

    [[ -z $lexi ]] && lexi="com.atproto.repo.uploadBlob"
    [[ -z $type ]] && type="*/*"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(atfile.xrpc.jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $(atfile.util.get_uas)" \
        --data-binary @"$file" | jq
}

## JetStream

function atfile.js.subscribe() {
    collection="$1"

    atfile.util.check_prog "websocat"
    websocat "$_endpoint_jetstream/subscribe?wantedCollections=$collection"
}

# Lexicons

## Records

function blue.zio.atfile.meta__unknown() {
    reason="$1"
    type="$2"
    
    if [[ -z "$reason" ]]; then
        reason="No metadata available for $type"
    fi

    echo "{
    \"\$type\": \"$_nsid_meta#unknown\",
    \"reason\": \"$reason\"
}"
}

function blue.zio.atfile.meta__audio() {
    file="$1"
    
    if [ ! -x "$(command -v mediainfo)" ]; then
        echo "$(blue.zio.atfile.meta__unknown "Unable to create record at time of upload (MediaInfo not installed)")"
        return
    fi
    
    audio="$(atfile.util.get_mediainfo_audio_json "$file")"
    duration=$(atfile.util.get_mediainfo_field "$file" "General" "Duration" null)
    format="$(atfile.util.get_mediainfo_field "$file" "General" "Format")"
    tag_album="$(atfile.util.get_mediainfo_field "$file" "General" "Album")"
    tag_albumArtist="$(atfile.util.get_mediainfo_field "$file" "General" "Album/Performer")"
    tag_artist="$(atfile.util.get_mediainfo_field "$file" "General" "Performer")"
    tag_date="$(atfile.util.get_mediainfo_field "$file" "General" "Original/Released_Date")"
    tag_disc=$(atfile.util.get_mediainfo_field "$file" "General" "Part/Position" null)
    tag_discTotal=$(atfile.util.get_mediainfo_field "$file" "General" "Part/Position_Total" null)
    tag_title="$(atfile.util.get_mediainfo_field "$file" "General" "Title")"
    tag_track=$(atfile.util.get_mediainfo_field "$file" "General" "Track/Position" null)
    tag_trackTotal=$(atfile.util.get_mediainfo_field "$file" "General" "Track/Position_Total" null)
    
    parsed_tag_date=""
    
    if [[ "${#tag_date}" > 4 ]]; then
        parsed_tag_date="$(atfile.util.get_date "$tag_date")"
    elif [[ "${#tag_date}" == 4 ]]; then
        parsed_tag_date="$(atfile.util.get_date "${tag_date}-01-01")"
    fi
    
    echo "{
    \"\$type\": \"$_nsid_meta#audio\",
    \"audio\": [ $audio ],
    \"duration\": $duration,
    \"format\": \"$format\",
    \"tags\": {
        \"album\": \"$tag_album\",
        \"album_artist\": \"$tag_albumArtist\",
        \"artist\": \"$tag_artist\",
        \"date\": $(atfile.util.get_date_json "$tag_date" "$parsed_tag_date"),
        \"disc\": {
            \"position\": $tag_disc,
            \"total\": $tag_discTotal
        },
        \"title\": \"$tag_title\",
        \"track\": {
            \"position\": $tag_track,
            \"total\": $tag_trackTotal
        }
    }
}"
}

function blue.zio.atfile.meta__photo() {
    file="$1"
    
    if [ ! -x "$(command -v exiftool)" ]; then
        echo "$(blue.zio.atfile.meta__unknown "Unable to create record during upload (ExifTool not installed)")"
        return
    fi

    artist="$(atfile.util.get_exiftool_field "$file" "Artist")"
    camera_aperture="$(atfile.util.get_exiftool_field "$file" "Aperture")"
    camera_exposure="$(atfile.util.get_exiftool_field "$file" "ExposureTime")"
    camera_flash="$(atfile.util.get_exiftool_field "$file" "Flash")"
    camera_focalLength="$(atfile.util.get_exiftool_field "$file" "FocalLength")"
    camera_iso="$(atfile.util.get_exiftool_field "$file" "ISO" null)"
    camera_make="$(atfile.util.get_exiftool_field "$file" "Make")"
    camera_mpx="$(atfile.util.get_exiftool_field "$file" "Megapixels" null)"
    camera_model="$(atfile.util.get_exiftool_field "$file" "Model")"
    date_create="$(atfile.util.get_exiftool_field "$file" "CreateDate")"
    date_modify="$(atfile.util.get_exiftool_field "$file" "ModifyDate")"
    date_tz="$(atfile.util.get_exiftool_field "$file" "OffsetTime" "+00:00")"
    dim_height="$(atfile.util.get_exiftool_field "$file" "ImageHeight" null)"
    dim_width="$(atfile.util.get_exiftool_field "$file" "ImageWidth" null)"
    gps_alt="$(atfile.util.get_exiftool_field "$file" "GPSAltitude" null)"
    gps_lat="$(atfile.util.get_exiftool_field "$file" "GPSLatitude" null)"
    gps_long="$(atfile.util.get_exiftool_field "$file" "GPSLongitude" null)"
    orientation="$(atfile.util.get_exiftool_field "$file" "Orientation")"
    software="$(atfile.util.get_exiftool_field "$file" "Software")"
    title="$(atfile.util.get_exiftool_field "$file" "Title")"
    
    date_create="$(atfile.util.parse_exiftool_date "$date_create" "$date_tz")"
    date_modify="$(atfile.util.parse_exiftool_date "$date_modify" "$date_tz")"
    
    [[ $gps_alt == +* ]] && gps_alt="${gps_alt:1}"
    [[ $gps_lat == +* ]] && gps_lat="${gps_lat:1}"
    [[ $gps_long == +* ]] && gps_long="${gps_long:1}"

    echo "{
    \"\$type\": \"$_nsid_meta#photo\",
    \"artist\": \"$artist\",
    \"camera\": {
        \"aperture\": \"$camera_aperture\",
        \"device\": {
            \"make\": \"$camera_make\",
            \"model\": \"$camera_model\"
        },
        \"exposure\": \"$camera_exposure\",
        \"flash\": \"$camera_flash\",
        \"focalLength\": \"$camera_focalLength\",
        \"iso\": $camera_iso,
        \"megapixels\": $camera_mpx
    },
    \"date\": {
        \"create\": $(atfile.util.get_date_json "$date_create"),
        \"modify\": $(atfile.util.get_date_json "$date_modify")
    },
    \"dimensions\": {
        \"height\": $dim_height,
        \"width\": $dim_width
    },
    \"gps\": {
        \"alt\": $gps_alt,
        \"lat\": $gps_lat,
        \"long\": "$gps_long"
    },
    \"orientation\": \"$orientation\",
    \"software\": \"$software\",
    \"title\": \"$title\"
}"
}

function blue.zio.atfile.meta__video() {
    file="$1"
    
    if [ ! -x "$(command -v mediainfo)" ]; then
        echo "$(blue.zio.atfile.meta__unknown "Unable to create record during upload (MediaInfo not installed)")"
        return
    fi
    
    artist="$(atfile.util.get_mediainfo_field "$file" "General" "Artist")"
    audio="$(atfile.util.get_mediainfo_audio_json "$file")"
    bitRate=$(atfile.util.get_mediainfo_field "$file" "General" "BitRate" null)
    date_create="",
    date_modify="",
    duration=$(atfile.util.get_mediainfo_field "$file" "General" "Duration" null)
    format="$(atfile.util.get_mediainfo_field "$file" "General" "Format")"
    gps_alt=0
    gps_lat=0
    gps_long=0
    title="$(atfile.util.get_mediainfo_field "$file" "General" "Title")"
    video="$(atfile.util.get_mediainfo_video_json "$file")"
    
    if [ -x "$(command -v exiftool)" ]; then
        date_create="$(atfile.util.get_exiftool_field "$file" "CreateDate")"
        date_modify="$(atfile.util.get_exiftool_field "$file" "ModifyDate")"
        date_tz="$(atfile.util.get_exiftool_field "$file" "OffsetTime" "+00:00")"
        gps_alt="$(atfile.util.get_exiftool_field "$file" "GPSAltitude" null)"
        gps_lat="$(atfile.util.get_exiftool_field "$file" "GPSLatitude" null)"
        gps_long="$(atfile.util.get_exiftool_field "$file" "GPSLongitude" null)"
        
        date_create="$(atfile.util.parse_exiftool_date "$date_create" "$date_tz")"
        date_modify="$(atfile.util.parse_exiftool_date "$date_modify" "$date_tz")"
    fi
    
    echo "{
    \"\$type\": \"$_nsid_meta#video\",
    \"artist\": \"$artist\",
    \"audio\": [ $audio ],
    \"biteRate\": $bitRate,
    \"date\": {
        \"create\": $(atfile.util.get_date_json "$date_create"),
        \"modify\": $(atfile.util.get_date_json "$date_modify")
    },
    \"duration\": $duration,
    \"format\": \"$format\",
    \"gps\": {
        \"alt\": $gps_alt,
        \"lat\": $gps_lat,
        \"long\": "$gps_long"
    },
    \"title\": \"$title\",
    \"video\": [ $video ]
}"
}

# NOTE: Never intended to be used from ATFile. Here for reference
function blue.zio.atfile.finger__browser() {
    url="$1"
    userAgent="$2"

    echo "{
    \"\$type\": \"blue.zio.atfile.finger#browser\",
    \"url\": \"$url\",
    \"userAgent\": \"$userAgent\"
}"
}

function blue.zio.atfile.finger__machine() {
    unset machine_host
    unset machine_id
    unset machine_os

    if [[ $_include_fingerprint == 1 ]]; then
        machine_id_file="/etc/machine-id"
        os_release_file="/etc/os-release"

        [[ -f "$machine_id_file" ]] && machine_id="$(cat "$machine_id_file")"

        case "$_os" in
            "haiku")
                os_version="$(uname -v | cut -d ' ' -f 1 | cut -d '+' -f 1)"
                
                case $os_version in
                    "hrev57937") os_version="R1/Beta5" ;;
                esac

                machine_host="$(hostname)"
                machine_os="Haiku $os_version"
                ;;
            "macos")
                os_version="$(sw_vers -productVersion | cut -d '.' -f 1,2)"
                
                case $os_version in
                    "13."*) os_version="$os_version Ventura" ;;
                    "14."*) os_version="$os_version Sonoma" ;;
                    "15."*) os_version="$os_version Sequoia" ;;
                esac

                machine_host="$(hostname)"
                machine_os="macOS $os_version"
                ;;
            *)
                os_name="$(atfile.util.get_var_from_file "$os_release_file" "NAME")"
                os_version="$(atfile.util.get_var_from_file "$os_release_file" "VERSION")"
            
                machine_host="$(hostname -s)"
                machine_os="$os_name $os_version"
                ;;
        esac
    fi

    echo "{
    \"\$type\": \"blue.zio.atfile.finger#machine\",
    \"app\": \"$(atfile.util.get_uas)\",
    \"id\": $([[ $(atfile.util.is_null_or_empty "$machine_id") == 0 ]] && echo "\"$machine_id\"" || echo "null"),
    \"host\": $([[ $(atfile.util.is_null_or_empty "$machine_host") == 0 ]] && echo "\"$machine_host\"" || echo "null"),
    \"os\": $([[ $(atfile.util.is_null_or_empty "$machine_os") == 0 ]] && echo "\"$machine_os\"" || echo "null")
}"
}

function blue.zio.atfile.lock() {
    lock="$1"
    
    echo "{
    \"lock\": $lock
}"
}

function blue.zio.atfile.upload() {
    blob_record="$1"
    createdAt="$2"
    file_hash="$3"
    file_hash_type="$4"
    file_modifiedAt="$5"
    file_name="$6"
    file_size="$7"
    file_type="$8"
    meta_record="$9"
    finger_record="${10}"
    
    [[ -z $finger_record ]] && finger_record="null"
    [[ -z $meta_record ]] && meta_record="null"

    echo "{
    \"createdAt\": \"$createdAt\",
    \"file\": {
        \"mimeType\": \"$file_type\",
        \"modifiedAt\": \"$file_modifiedAt\",
        \"name\": \"$file_name\",
        \"size\": $file_size
    },
    \"checksum\": {
        \"algo\": \"$file_hash_type\",
        \"hash\": \"$file_hash\"
    },
    \"finger\": $finger_record,
    \"meta\": $meta_record,
    \"blob\": $blob_record
}"
}

function blue.zio.meta.profile() {
    nickname="$1"
    
    echo "{
    \"nickname\": \"$nickname\"  
}"
}

## Queries

function app.bsky.actor.getProfile() {
    actor="$1"
    
    atfile.xrpc.get "app.bsky.actor.getProfile" "actor=$actor" 
}

function com.atproto.repo.createRecord() {
    repo="$1"
    collection="$2"
    record="$3"
    
    atfile.xrpc.post "com.atproto.repo.createRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"record\": $record }"
}

function com.atproto.repo.deleteRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"

    atfile.xrpc.post "com.atproto.repo.deleteRecord" "{ \"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\" }"
}

function com.atproto.repo.getRecord() {
    repo="$1"
    collection="$2"
    key="$3"

    atfile.xrpc.get "com.atproto.repo.getRecord" "repo=$repo&collection=$collection&rkey=$key"
}

function com.atproto.repo.listRecords() {
    repo="$1"
    collection="$2"
    cursor="$3"
    
    atfile.xrpc.get "com.atproto.repo.listRecords" "repo=$repo&collection=$collection&limit=$_max_list&cursor=$cursor"
}

function com.atproto.repo.putRecord() {
    repo="$1"
    collection="$2"
    rkey="$3"
    record="$4"
    
    atfile.xrpc.post "com.atproto.repo.putRecord" "{\"repo\": \"$repo\", \"collection\": \"$collection\", \"rkey\": \"$rkey\", \"record\": $record }"
}

function com.atproto.identity.resolveHandle() {
    handle="$1"

    atfile.xrpc.get "com.atproto.identity.resolveHandle" "handle=$handle"
}

function com.atproto.server.getSession() {
    atfile.xrpc.get "com.atproto.server.getSession"
}

function com.atproto.sync.getBlob() {
    did="$1"
    cid="$2"

    atfile.xrpc.get "com.atproto.sync.getBlob" "did=$did&cid=$cid" "*/*"
}

function com.atproto.sync.listBlobs() {
    did="$1"
    cursor="$2"
    
    atfile.xrpc.get "com.atproto.sync.listBlobs" "did=$did&limit=$_max_list&cursor=$cursor"
}

function com.atproto.sync.uploadBlob() {
    file="$1"
    atfile.xrpc.post_blob "$1" | jq -r ".blob"
}

# Commands

function atfile.invoke.blob_list() {
    cursor="$1"
    success=1
    
    atfile.say.debug "Getting blobs...\n↳ Repo: $_username"
    blobs="$(com.atproto.sync.listBlobs "$_username" "$cursor")"
    success="$(atfile.util.is_xrpc_success $? "$blobs")"

    if [[ $success == 1 ]]; then
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
    file="$(atfile.util.get_file_path "$1")"
    [[ ! -f "$file" ]] && atfile.die "File '$file' does not exist"
    atfile.say.debug "Uploading blob...\n↳ File: $file"
    com.atproto.sync.uploadBlob "$file" | jq
}

function atfile.invoke.debug() {
    prog_not_installed_placeholder="(Not Installed)"

    function atfile.invoke.debug.print_envvar() {
        variable_name="${_envvar_prefix}_$1"
        variable_default="$2"
        
        unset output
        
        output="$variable_name: $(atfile.util.get_envvar "$variable_name" "$variable_default")"
        [[ -n "$variable_default" ]] && output+=" [$variable_default]"
        
        echo -e "↳ $output"
    }

    function atfile.invoke.debug.print_prog_version() {
        prog="$1"
        version_arg="$2"

        [[ -z "$version_arg" ]] && version_arg="--version"

        if [ -x "$(command -v $prog)" ]; then
            eval "$prog $version_arg"
        else
            echo "$prog_not_installed_placeholder"
        fi
    }

    if [[ $_output_json == 1 ]]; then
        atfile.die "Command not available as JSON"
    fi
    
    md5sum_version="$(atfile.invoke.debug.print_prog_version "md5sum")"
    mediainfo_version="$(atfile.invoke.debug.print_prog_version "mediainfo")"
    os="$(atfile.util.get_finger_record | jq -r ".os")"
    
    if [[ "$md5sum_version" != "$prog_not_installed_placeholder" ]]; then
        md5sum_version="$(echo "$md5sum_version" | head -n 1)"
        if [[ "$md5sum_version" == *GNU* ]]; then
            md5sum_version="$(echo "$md5sum_version" | cut -d " " -f 4) (GNU)"
        fi
    fi
    
    if [[ "$mediainfo_version" != "$prog_not_installed_placeholder" ]]; then
        mediainfo_version="$(echo "$mediainfo_version" | grep "MediaInfoLib" | cut -d "v" -f 2)"
    fi
    
    debug_output="ATFile
↳ Version: $_version
↳ UAS: $(atfile.util.get_uas)
Variables
$(atfile.invoke.debug.print_envvar "DEBUG" $_debug_default)
↳ ${_envvar_prefix}_DIST_PASSWORD: $([[ -n $(atfile.util.get_envvar "${_envvar_prefix}_DIST_PASSWORD") ]] && echo "(Set)")
$(atfile.invoke.debug.print_envvar "DIST_USERNAME" $_dist_username_default)
$(atfile.invoke.debug.print_envvar "ENDPOINT_PDS")
$(atfile.invoke.debug.print_envvar "ENDPOINT_PLC_DIRECTORY" $_endpoint_plc_directory_default)
$(atfile.invoke.debug.print_envvar "ENDPOINT_RESOLVE_HANDLE" $_endpoint_resolve_handle_default)
$(atfile.invoke.debug.print_envvar "FMT_BLOB_URL" "$_fmt_blob_url_default")
$(atfile.invoke.debug.print_envvar "FMT_OUT_FILE" "$_fmt_out_file_default")
$(atfile.invoke.debug.print_envvar "INCLUDE_FINGERPRINT" $_include_fingerprint_default)
$(atfile.invoke.debug.print_envvar "MAX_LIST" $_max_list_default)
$(atfile.invoke.debug.print_envvar "OUTPUT_JSON" $_output_json_default)
$(atfile.invoke.debug.print_envvar "SKIP_AUTH_CHECK" $_skip_auth_check_default)
$(atfile.invoke.debug.print_envvar "SKIP_COPYRIGHT_WARN" $_skip_copyright_warn_default)
$(atfile.invoke.debug.print_envvar "SKIP_NI_EXIFTOOL" $_skip_ni_exiftool_default)
$(atfile.invoke.debug.print_envvar "SKIP_NI_MEDIAINFO" $_skip_ni_mediainfo_default)
↳ ${_envvar_prefix}_PASSWORD: $([[ -n $(atfile.util.get_envvar "${_envvar_prefix}_PASSWORD") ]] && echo "(Set)")
$(atfile.invoke.debug.print_envvar "USERNAME")
Environment
↳ OS: $os
↳ Shell: $SHELL
↳ Path: $PATH
Deps
↳ Bash: $BASH_VERSION
↳ curl: $(atfile.invoke.debug.print_prog_version "curl" "--version" | head -n 1 | cut -d " " -f 2)
↳ ExifTool: $(atfile.invoke.debug.print_prog_version "exiftool" "-ver")
↳ jq: $(atfile.invoke.debug.print_prog_version "jq" | sed -e "s|jq-||g")
↳ md5sum: $md5sum_version
↳ MediaInfo: $mediainfo_version
Misc.
↳ md5sum Output: $(md5sum "$_prog_path")
↳ Now: $_now
↳ Rows: $(atfile.util.get_term_rows)"
    
    atfile.say "$debug_output"
}

function atfile.invoke.delete() {
    key="$1"
    success=1

    lock_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.lock" "$key")"

    if [[ $(atfile.util.is_xrpc_success $? "$lock_record") == 1 ]] && [[ $(echo "$lock_record" | jq -r ".value.lock") == true ]]; then
        atfile.die "Unable to delete '$key' — file is locked\n       Run \`$_prog unlock $key\` to unlock file"
    fi

    record="$(com.atproto.repo.deleteRecord "$_username" "$_nsid_upload" "$key")"
    
    if [[ $(atfile.util.is_xrpc_success $? "$record") == 1 ]]; then
        if [[ $_output_json == 1 ]]; then
            echo "{ \"deleted\": true }" | jq
        else
            echo "Deleted: $key"
        fi
    else
        atfile.die "Unable to delete '$key'"
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
            echo -e "{ \"decrypted\": $is_decrypted, \"name\": \"$(basename "${downloaded_file}")\", \"path\": \"$(realpath "${downloaded_file}")\" }" | jq
        else
            echo -e "Downloaded: $key"
            [[ $decrypt == 1 ]] && echo "Decrypted: $downloaded_file"
            echo -e "↳ Path: $(realpath "$downloaded_file")"
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
    success=1
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    success="$(atfile.util.is_xrpc_success $? "$record")"
    
    if [[ $success == 1 ]]; then
        blob_url="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"

        if [[ $_output_json == 1 ]]; then
            echo -e "{\"url\": \"$blob_url\" }" | jq
        else
            echo "$blob_url"
        fi
    else
        atfile.die "Unable to get '$key'"
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
        [[ "$(atfile.util.is_xrpc_success $? "$record")" == 0 ]] && atfile.die.gui "Unable to get '$key'"

        blob_cid="$(echo $record | jq -r ".value.blob.ref.\"\$link\"")"
        blob_uri="$(atfile.util.build_blob_uri "$_username" "$blob_cid")"
        file_type="$(echo $record | jq -r '.value.file.mimeType')"

        if [[ $_os == "linux" ]] && \
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
                    tmp_path="$_dir_blobs_tmp/$blob_cid"

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
    success=1
    
    atfile.say.debug "Getting records...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username"
    records="$(com.atproto.repo.listRecords "$_username" "$_nsid_upload" "$cursor")"
    success="$(atfile.util.is_xrpc_success $? "$records")"
   
    if [[ $success == 1 ]]; then
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
        atfile.die "Unable to list files"
    fi
}

function atfile.invoke.lock() {
    key="$1"
    locked=$2
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    upload_record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    success=$(atfile.util.is_xrpc_success $? "$upload_record")
    
    if [[ $success == 1 ]]; then        
        if [[ $locked == 1 ]]; then
            locked=true
        else
            locked=false
        fi
        
        lock_record="$(blue.zio.atfile.lock $locked)"
        
        atfile.say.debug "Updating record...\n↳ NSID: $_nsid_lock\n↳ Repo: $_username\n↳ Key: $key"
        record="$(com.atproto.repo.putRecord "$_username" "$_nsid_lock" "$key" "$lock_record")"
        success=$(atfile.util.is_xrpc_success $? "$record")
    fi
    
    if [[ $(atfile.util.is_xrpc_success $? "$record") == 1 ]]; then
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
            atfile.die "Unable to lock '$key'"
        else
            atfile.die "Unable to unlock '$key'"
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

function atfile.invoke.print() {
    key="$1"
    success=1
    
    atfile.say.debug "Getting record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
    record="$(com.atproto.repo.getRecord "$_username" "$_nsid_upload" "$key")"
    [[ $? != 0 || -z "$record" || "$record" == "{}" || "$record" == *"\"error\":"* ]] && success=0
    
    if [[ $success == 1 ]]; then
        blob_uri="$(atfile.util.build_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        
        curl -H "$(atfile.util.get_uas)" -s -L "$blob_uri" --output -
        [[ $? != 0 ]] && success=0
    fi
    
    if [[ $success != 1 ]]; then
        atfile.die "Unable to cat '$key'"
    fi
}

function atfile.invoke.profile() {
    nick="$1"
    
    profile_record="$(blue.zio.meta.profile "$1")"
    atfile.say.debug "Updating record...\n↳ NSID: $_nsid_profile\n↳ Repo: $_username\n↳ Key: self"
    record="$(com.atproto.repo.putRecord "$_username" "$_nsid_profile" "self" "$profile_record")"
    
    if [[ $(atfile.util.is_xrpc_success $? "$record") == 1 ]]; then
        atfile.say.debug "Getting record...\n↳ NSID: $_nsid_profile\n↳ Repo: $_username\n↳ Key: self"
        record="$(com.atproto.repo.getRecord "$_username" "$_nsid_profile" "self")"
    
        if [[ $_output_json == 1 ]]; then
            echo -e "{ \"profile\": $(echo "$record" | jq -r ".value") }" | jq
        else
            echo "Updated profile"
            echo "↳ Nickname: $(echo "$record" | jq -r ".value.nickname")"
        fi
    else
        atfile.die "Unable to update profile"
    fi
}

function atfile.invoke.release() {
    [[ $_is_git == 0 ]] && atfile.die "Cannot run 'release' outside of Git directory"
    [[ $_version == *"+"* ]] && atfile.die "Not a stable version ($_version)"

    commit_hash="$(git rev-parse HEAD)"
    commit_date="$(git show --no-patch --format=%ci $commit_hash)"
    dist_file="$(echo "$_prog" | cut -d "." -f 1)-${_version}.sh"
    dist_path="$_prog_dir/$dist_file"
    parsed_version="$(atfile.util.parse_version "$_version")"

    atfile.say "Copying working version to '$dist_file'..."
    cp -f "$_prog_path" "$dist_path"
    [[ $? != 0 ]] && atfile.die "Unable to create '$dist_path'"

    atfile.invoke.upload "$dist_path" "" "$parsed_version"
    [[ $? != 0 ]] && atfile.die "Unable to upload '$dist_path'"
    echo "---"

    latest_release_record="{
    \"version\": \"$_version\",
    \"releasedAt\": \"$(atfile.util.get_date "$_commit_date")\",
    \"commit\": \"$commit_hash\" 
}"

    atfile.say "Updating latest record to $_version..."
    atfile.invoke.manage_record put "at://$_username/self.atfile.latest/self" "$latest_release_record" &> /dev/null
    
    rm -f "$dist_path"
}

function atfile.invoke.resolve() {
    actor="$1"

    atfile.say.debug "Resolving actor '$actor'..."
    resolved_did="$(atfile.util.resolve_identity "$actor")"

    alias="$(echo $resolved_did | cut -d "|" -f 3)"
    did="$(echo $resolved_did | cut -d "|" -f 1)"
    did_doc="$(echo $resolved_did | cut -d "|" -f 4)/$did"
    did_type="did:$(echo $did | cut -d ":" -f 2)"
    handle="$(echo $resolved_did | cut -d "|" -f 3 | cut -d "/" -f 3)"
    pds="$(echo $resolved_did | cut -d "|" -f 2)"
    pds_name="$(atfile.util.get_pds_pretty "$pds")"
    atfile.say.debug "Getting PDS version for '$pds'..."
    pds_version="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -l -X GET "$pds/xrpc/_health" | jq -r '.version')"

    [[ "$did" == "null" ]] && atfile.die "Unable to resolve '$actor'"

    case "$did_type" in
        "did:web")
            did_doc="$(atfile.util.get_didweb_doc_url "$actor")"
            ;;
    esac

    if [[ $_output_json == 1 ]]; then
        did_doc_data="$(curl -H "User-Agent: $(atfile.util.get_uas)" -s -l -X GET "$did_doc")"
    
        echo -e "{
    \"did\": \"$did\",
    \"doc\": {
        \"data\": $did_doc_data,
        \"url\": \"$did_doc\"
    },
    \"handle\": \"$handle\",
    \"pds\": {
        \"endpoint\": \"$pds\",
        \"name\": \"$pds_name\",
        \"version\": \"$pds_version\"
    },
    \"type\": \"$did_type\"
}" | jq
    else
        echo "$did"
        echo "↳ Type: $did_type"
        echo " ↳ Doc: $did_doc"
        echo "↳ Handle: @$handle"
        echo "↳ PDS: $pds_name"
        echo " ↳ Endpoint: $pds"
        [[ $pds_version != "null" ]] && echo " ↳ Version: $pds_version"
    fi
}

function atfile.invoke.stream() {
    collection="$1"
    [[ -z "$collection" ]] && collection="blue.zio.atfile.upload"
    atfile.js.subscribe "$collection"
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

# TODO: Validate checksum
function atfile.invoke.update() {
    if [[ $_output_json == 1 ]]; then
        atfile.die "Command not available as JSON"
    fi

    atfile.util.override_actor "$_meta_did"
    atfile.util.print_override_actor_debug

    atfile.say.debug "Getting latest release..."
    latest_release_record="$(com.atproto.repo.getRecord "$_meta_did" "self.atfile.latest" "self")"
    [[ $(atfile.util.is_xrpc_success $? "$latest_release_record") != 1 ]] && atfile.die "Unable to get latest version"

    latest_version="$(echo "$latest_release_record" | jq -r '.value.version')"
    latest_version_commit="$(echo "$latest_release_record" | jq -r '.value.commit')"
    latest_version_date="$(echo "$latest_release_record" | jq -r '.value.releasedAt')"
    parsed_latest_version="$(atfile.util.parse_version $latest_version)"
    parsed_running_version="$(atfile.util.parse_version $_version)"
    
    atfile.say.debug "Version\n↳ Latest: $latest_version ($parsed_latest_version)\n ↳ Date: $latest_version_date\n ↳ Commit: $latest_version_commit\n↳ Running: $_version ($parsed_running_version)"

    if [[ $_version == *+git* ]]; then
        atfile.die "Cannot update Git version ($_version)"
    fi
    
    if [[ $(( $parsed_latest_version > $parsed_running_version )) == 1 ]]; then
        temp_updated_path="$_prog_dir/${_prog}-${latest_version}.tmp"
        
        atfile.say.debug "Touching temporary path ($temp_updated_path)..."
        touch "$temp_updated_path"
        [[ $? != 0 ]] && atfile.die "Unable to create temporary file (do you have permission?)"
        
        atfile.say.debug "Getting blob URL for $latest_version ($parsed_latest_version)..."
        blob_url="$(atfile.invoke.get_url $parsed_latest_version)"
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
                atfile.say "😎 Updated to $latest_version!"
                exit 0
            fi
        else
            atfile.die "Unable to download latest version"
        fi
    else
        atfile.say "No updates found"
    fi
}

function atfile.invoke.upload() {
    file="$(atfile.util.get_file_path "$1")"
    recipient="$2"
    key="$3"
    success=1
    
    [[ ! -f "$file" ]] && atfile.die "File '$file' does not exist"

    if [[ $_output_json == 0 ]]; then
        if [[ "$_server" == "https://bsky.social" ]] || [[ "$_server" == *".bsky.network" ]]; then
            atfile.util.print_copyright_warning
        fi
    fi
    
    if [[ -n $recipient ]]; then
        file_crypt="$(dirname "$file")/$(basename "$file").gpg"
        
        [[ $_output_json == 0 ]] && echo -e "Encrypting '$file_crypt'..."
        gpg --yes --quiet --recipient $recipient --output "$file_crypt" --encrypt "$file"
        [[ $? != 0 ]] && success=0
        
        if [[ $success == 1 ]]; then
            file="$file_crypt"
        else
            rm -f "$file_crypt"
            atfile.die "Unable to encrypt '$(basename "$file")'"
        fi
    fi

    if [[ $success == 1 ]]; then
        unset file_date
        unset file_size
        unset file_type

        case "$_os" in
            "haiku")
                haiku_file_attr="$(catattr BEOS:TYPE "$file" 2> /dev/null)"
                [[ $? == 0 ]] && file_type="$(echo "$haiku_file_attr" | cut -d ":" -f 3 | xargs)"

                file_date="$(atfile.util.get_date "$(stat -c '%y' "$file")")"
                file_size="$(stat -c %s "$file")"
                ;;
            "macos")
                file_date="$(atfile.util.get_date "$(stat -f '%Sm' -t "%Y-%m-%dT%H:%M:%SZ" "$file")")"
                file_size="$(stat -f '%z' "$file")"
                ;;
            *)
                file_date="$(atfile.util.get_date "$(stat -c '%y' "$file")")"
                file_size="$(stat -c %s "$file")"
                ;;
        esac

        if [ -x "$(command -v file)" ]; then
            file_type="$(file -b --mime-type "$file")"
        fi

        file_hash="$(atfile.util.get_md5 "$file")"
        file_hash_type="md5"
        file_name="$(basename "$file")"

        if [[ -z "$file_hash" ]]; then
            file_hash_type="none"
        fi
        
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

        atfile.say.debug "File: $file\n↳ Date: $file_date\n↳ Hash: $file_hash ($file_hash_type)\n↳ Name: $file_name\n↳ Size: $file_size\n↳ Type: $file_type_emoji $file_type"
        
        unset file_finger_record
        unset file_meta_record
        
        file_finger_record="$(atfile.util.get_finger_record)"
        file_meta_record="$(atfile.util.get_meta_record "$file" "$file_type")"
        
        [[ $_output_json == 0 ]] && echo "Uploading '$file'..."
        blob="$(com.atproto.sync.uploadBlob "$file")"
        success=$(atfile.util.is_xrpc_success $? "$blob")
        
        atfile.say.debug "Uploading blob...\n↳ Ref: $(echo "$blob" | jq -r ".ref.\"\$link\"")"
    
        if [[ $success == 1 ]]; then
            file_record="$(blue.zio.atfile.upload "$blob" "$_now" "$file_hash" "$file_hash_type" "$file_date" "$file_name" "$file_size" "$file_type" "$file_meta_record" "$file_finger_record")"
            
            if [[ -n "$key" ]]; then
                atfile.say.debug "Updating record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username\n↳ Key: $key"
                record="$(com.atproto.repo.putRecord "$_username" "$_nsid_upload" "$key" "$file_record")"
                success=$(atfile.util.is_xrpc_success $? "$record")
            else
                atfile.say.debug "Creating record...\n↳ NSID: $_nsid_upload\n↳ Repo: $_username"
                record="$(com.atproto.repo.createRecord "$_username" "$_nsid_upload" "$file_record")"
                success=$(atfile.util.is_xrpc_success $? "$record")
            fi
        fi
    fi
    
    if [[ -n $recipient ]]; then
        rm -f "$file"
    fi

    if [[ $success == 1 ]]; then
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
        atfile.die "Unable to upload '$file'"
    fi
}

function atfile.invoke.usage() {
    if [[ $_output_json == 1 ]]; then
        atfile.die "Command not available as JSON"
    fi

    handle="$(atfile.util.resolve_identity "$_meta_did" | cut -d "|" -f 3 | sed -s 's/at:\/\///g')"

# ------------------------------------------------------------------------------
    usage_commands="upload <file> [<key>]
        Upload new file to the PDS
        ⚠️  ATProto records are public: do not upload sensitive files
        
    list [<cursor>] [<actor>]
    list <actor> [<cursor>]
        List all uploaded files. Only $_max_list items can be displayed; to
        paginate, use the last Key for <cursor>

    fetch <key> [<actor>]
        Download an uploaded file
        
    cat <key> [<actor>]
        Print (don't download) an uploaded file to the shell
           
    url <key> [<actor>]
        Get blob URL for an uploaded file
        
    info <key> [<actor>]
        Get full details for an uploaded file

    delete <key>
        Delete an uploaded file
        ⚠️  No confirmation is asked before deletion

    lock <key>
    unlock <key>
        Lock (or unlock) an uploaded file to prevent it from unintended
        deletions
        ⚠️  Other clients may be able to delete the file. This is intended as a
           safety-net to avoid inadvertently deleting the wrong file

    upload-crypt <file> <recipient> [<key>]
        Encrypt file (with GPG) for <recipient> and upload to the PDS
        ℹ️  Make sure the necessary GPG key has been imported first
        
    fetch-crypt <file> [<actor>]
        Download an uploaded encrypted file and attempt to decrypt it (with GPG)
        ℹ️  Make sure the necessary GPG key has been imported first

    nick <nick>
        Set nickname
        ℹ️  Intended for future use"

    usage_commands_lifecycle="update
        Check for updates and update if outdated

    toggle-mime
        Install/uninstall desktop file to handle atfile:/at: protocol"

    usage_commands_tools="blob list
    blob upload <path>
        Manage blobs on authenticated repository

    handle <at-uri>
        Open at:// URI with relevant App

    handle <atfile-uri> [<handler>]
        Open atfile:// URI with relevant App
        ℹ️  Set <handler> to a .desktop entry to force the application
           <atfile-uri> opens with

    record add <record-json> [<collection>]
    record get <key> [<collection>] [<actor>]
    record get <at-uri>
    record put <key> <record-json> [<collection>]
    record put <at-uri> <record-json>
    record rm <key> [<collection>]
    record rm <at-uri>
        Manage records on a repository
        ⚠️  No validation is performed. Here be dragons!
        ℹ️  <collection> defaults to '$_nsid_upload'
        
    resolve <actor>
        Get details for <actor>

    stream <collection>
        Stream records from Jetstream"

    usage_envvars="${_envvar_prefix}_USERNAME <string> (required)
        Username of the PDS user (handle or DID)
    ${_envvar_prefix}_PASSWORD <string> (required)
        Password of the PDS user
        An App Password is recommended (https://bsky.app/settings/app-passwords)
        
    ${_envvar_prefix}_INCLUDE_FINGERPRINT <bool¹> (default: $_include_fingerprint_default)
        Apply machine fingerprint to uploaded files
    ${_envvar_prefix}_OUTPUT_JSON <bool¹> (default: $_output_json_default)
        Print all commands (and errors) as JSON
        ⚠️  When sourcing, sets to 1
    ${_envvar_prefix}_MAX_LIST <int> (default: $_max_list_default)
        Maximum amount of items in any lists
        ℹ️  Default value is calculated from your terminal's height
        ⚠️  When output is JSON (${_envvar_prefix}_OUTPUT_JSON=1), sets to 100
    ${_envvar_prefix}_FMT_BLOB_URL <string> (default: $_fmt_blob_url_default)
        Format for blob URLs. Fragments:
        * [server]: PDS endpoint
        * [did]: Actor DID
        * [cid]: Blob CID
    ${_envvar_prefix}_FMT_OUT_FILE <string> (default: $_fmt_out_file_default)
        Format for fetched filenames. Fragments:
        * [key]: Record key of uploaded file
        * [name]: Original name of uploaded file
    ${_envvar_prefix}_SKIP_AUTH_CHECK <bool¹> (default: $_skip_auth_check_default)
        Skip session validation on startup
        If you're confident your credentials are correct, and \$${_envvar_prefix}_USERNAME
        is a DID (*not* a handle), this will drastically improve performance!
    ${_envvar_prefix}_SKIP_COPYRIGHT_WARN <bool¹> (default: $_skip_copyright_warn_default)
        Do not print copyright warning when uploading files to
        https://bsky.social
    ${_envvar_prefix}_SKIP_NI_EXIFTOOL <bool¹> (default: $_skip_ni_exiftool_default)
        Do not check if ExifTool is installed
        ⚠️  If Exiftool is not installed, the relevant metadata records will
           not be created:
           * image/*: $_nsid_meta#photo
    ${_envvar_prefix}_SKIP_NI_MEDIAINFO <bool¹> (default: $_skip_ni_mediainfo_default)
        Do not check if MediaInfo is installed
        ⚠️  If MediaInfo is not installed, the relevant metadata records will
           not be created:
           * audio/*: $_nsid_meta#audio
           * video/*: $_nsid_meta#video

    ${_envvar_prefix}_ENDPOINT_JETSTREAM <url> (default: $_endpoint_jetstream_default)
        Endpoint of the Jetstream relay
    ${_envvar_prefix}_ENDPOINT_PDS <url>
        Endpoint of the PDS
        ℹ️  Your PDS is resolved from your username. Set to override it (or if
           resolving fails)
    ${_envvar_prefix}_ENDPOINT_PLC_DIRECTORY <url> (default: ${_endpoint_plc_directory_default}$([[ $_endpoint_plc_directory_default == *"zio.blue" ]] && echo "²"))
        Endpoint of the PLC directory
    ${_envvar_prefix}_ENDPOINT_RESOLVE_HANDLE <url> (default: ${_endpoint_resolve_handle_default}$([[ $_endpoint_plc_directory_default == *"zio.blue" ]] && echo "²"))
        Endpoint of the PDS/AppView used for handle resolving
           
    ${_envvar_prefix}_DEBUG <bool¹> (default: $_debug_default)
        Print debug outputs
        ⚠️  When output is JSON (${_envvar_prefix}_OUTPUT_JSON=1), sets to 0
           
    ¹ A bool in Bash is 1 (true) or 0 (false)
    ² These servers are ran by @ducky.ws (and @astra.blue). You can trust us!"

    usage_files="$_path_envvar
        List of key/values of the above environment variables. Exporting these
        on the shell (with \`export \$ATFILE_VARIABLE\`) overrides these values

    $_dir_cache/
        Cache and temporary storage"

    usage="ATFile | 📦 ➔ 🦋
    Store and retrieve files on the ATmosphere
    
    Version $_version
    (c) $_meta_year $_meta_author <$_meta_repo>
    Licensed as MIT License ✨
    
    😎 Stay updated with \`$_prog update\`
       Follow on Bluesky on @$handle
    
Usage
    $_prog <command> [<arguments>]
    $_prog at://<actor>[/<collection>/<rkey>]
    $_prog atfile://<actor>/<key>

Commands
    $usage_commands

Commands ➔ Lifecycle
    $usage_commands_lifecycle

Commands ➔ Tools
    $usage_commands_tools

Environment Variables
    $usage_envvars

Files
    $usage_files
"

if [[ $_debug == 1 ]]; then
    atfile.say.debug "Printing help..."
    echo -e "$usage"
else
    echo -e "$usage" | less
fi

# ------------------------------------------------------------------------------
}

# Main

## Global variables

### General

_prog="$(basename "$(atfile.util.get_realpath "$0")")"
_prog_dir="$(dirname "$(atfile.util.get_realpath "$0")")"
_prog_path="$(atfile.util.get_realpath "$0")"
_version="0.6.7"
_command="$1"
_command_full="$@"
_envvar_prefix="ATFILE"
_is_sourced=0
_meta_author="Ducky"
_meta_did="did:plc:wennm3p5pufuib7vo5ex4sqw" # @atfile.zio.blue
_meta_repo="https://github.com/electricduck/atfile"
_meta_year="2024"
_now="$(atfile.util.get_date)"
_os="$(atfile.util.get_os)"

### Paths

_dir_cache="$HOME/.cache/atfile"
_dir_blobs_tmp="/tmp/at-blobs"
_path_envvar="$HOME/.config/atfile.env"

case "$_os" in
    "haiku")
        _dir_cache="$HOME/config/cache"
        _path_envvar="$HOME/config/settings/atfile.env"
        ;;
esac

### Envvars

#### Defaults

_debug_default=0
_dist_username_default="$_meta_did"
_endpoint_jetstream_default="wss://jetstream.atproto.tools"
_endpoint_resolve_handle_default="https://zio.blue" # lol wtf is bsky.social
_endpoint_plc_directory_default="https://plc.zio.blue"
_fmt_blob_url_default="[server]/xrpc/com.atproto.sync.getBlob?did=[did]&cid=[cid]"
_fmt_out_file_default="[key]__[name]"
_include_fingerprint_default=0
_max_list_buffer=6
_max_list_default=$(( $(atfile.util.get_term_rows) - $_max_list_buffer ))
_output_json_default=0
_skip_auth_check_default=0
_skip_copyright_warn_default=0
_skip_ni_exiftool_default=0
_skip_ni_mediainfo_default=0

#### Fallbacks

_endpoint_plc_directory_fallback="https://plc.directory"

#### Set

_debug="$(atfile.util.get_envvar "${_envvar_prefix}_DEBUG" $_debug_default)"
_dist_password="$(atfile.util.get_envvar "${_envvar_prefix}_DIST_PASSWORD" $_dist_password_default)"
_dist_username="$(atfile.util.get_envvar "${_envvar_prefix}_DIST_USERNAME" $_dist_username_default)"
_fmt_blob_url="$(atfile.util.get_envvar "${_envvar_prefix}_FMT_BLOB_URL" "$_fmt_blob_url_default")"
_fmt_out_file="$(atfile.util.get_envvar "${_envvar_prefix}_FMT_OUT_FILE" "$_fmt_out_file_default")"
_include_fingerprint="$(atfile.util.get_envvar "${_envvar_prefix}_INCLUDE_FINGERPRINT" "$_include_fingerprint_default")"
_endpoint_jetstream="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_JETSTREAM" "$_endpoint_jetstream_default")"
_endpoint_plc_directory="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_PLC_DIRECTORY" "$_endpoint_plc_directory_default")"
_endpoint_resolve_handle="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_RESOLVE_HANDLE" "$_endpoint_resolve_handle_default")"
_max_list="$(atfile.util.get_envvar "${_envvar_prefix}_MAX_LIST" "$_max_list_default")"
_output_json="$(atfile.util.get_envvar "${_envvar_prefix}_OUTPUT_JSON" "$_output_json_default")"
_server="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_PDS")"
_skip_auth_check="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_AUTH_CHECK" "$_skip_auth_check_default")"
_skip_copyright_warn="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_COPYRIGHT_WARN" "$_skip_copyright_warn_default")"
_skip_ni_exiftool="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_NI_EXIFTOOL" "$_skip_ni_exiftool_default")"
_skip_ni_mediainfo="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_NI_MEDIAINFO" "$_skip_ni_mediainfo_default")"
_password="$(atfile.util.get_envvar "${_envvar_prefix}_PASSWORD")"
_test_desktop_uas="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
_username="$(atfile.util.get_envvar "${_envvar_prefix}_USERNAME")"

### NSIDs

_nsid_prefix="blue.zio"
_nsid_lock="${_nsid_prefix}.atfile.lock"
_nsid_meta="${_nsid_prefix}.atfile.meta"
_nsid_profile="${_nsid_prefix}.meta.profile"
_nsid_upload="${_nsid_prefix}.atfile.upload"

## Source detection

if [[ "$0" != "$BASH_SOURCE" ]]; then
    _debug=0
    _is_sourced=1
    _output_json=1
fi

## "Hello, world!"

atfile.say.debug "Starting up..."

## Cache/Temp

atfile.say.debug "Creating necessary directories..."
atfile.util.create_dir "$_dir_cache"
atfile.util.create_dir "$_dir_blobs_tmp"

## Git detection

if [ -x "$(command -v git)" ] && [[ -d "$_prog_dir/.git" ]] && [[ "$(realpath $(pwd))" == "$_prog_dir" ]]; then
    atfile.say.debug "Getting tag from Git..."
    git describe --exact-match --tags > /dev/null 2>&1
    [[ $? != 0 ]] && _version+="+git.$(git rev-parse --short HEAD)"
    _is_git=1
fi

## Envvar correction

if [[ $_output_json == 1 ]] && [[ $_max_list == $_max_list_default ]]; then
    _max_list=100
fi

[[ $(( $_max_list > 100 )) == 1 ]] && _max_list="100"

## Program detection

_prog_hint_jq="https://jqlang.github.io/jq"

if [[ "$_os" == "haiku" ]]; then
    _prog_hint_jq="pkgman install jq"
fi

atfile.say.debug "Checking required programs..."
atfile.util.check_prog "curl"
atfile.util.check_prog "jq" "$_prog_hint_jq"
atfile.util.check_prog "md5sum"
atfile.util.check_prog "xargs"

## Lifecycle commands

if [[ $_is_sourced == 0 ]] && [[ $_command == "" || $_command == "help" || $_command == "h" || $_command == "--help" || $_command == "-h" ]]; then
    atfile.invoke.usage
    exit 0
fi

if [[ $_command == "update" ]]; then
    atfile.invoke.update
    exit 0
fi

if [[ $_command == "version" || $_command == "--version" ]]; then
    atfile.say.debug "Printing version..."
    echo -e "$_version"
    exit 0
fi

## Command aliases

if [[ $_is_sourced == 0 ]]; then
    case "$_command" in
        "open"|"print"|"c") _command="cat" ;;
        "rm") _command="delete" ;;
        "download"|"f"|"d") _command="fetch" ;;
        "download-crypt"|"fc"|"dc") _command="fetch-crypt" ;;
        "at") _command="handle" ;;
        "get"|"i") _command="info" ;;
        "ls") _command="list" ;;
        "did") _command="resolve" ;;
        "js") _command="stream" ;;
        "ul"|"u") _command="upload" ;;
        "ub") _command="upload-blob" ;;
        "uc") _command="upload-crypt" ;;
        "get-url"|"b") _command="url" ;;
    esac
fi

## Required variables detection

atfile.say.debug "Checking required variables..."
[[ -z "$_username" ]] && atfile.die "\$${_envvar_prefix}_USERNAME not set"
[[ -z "$_password" ]] && atfile.die "\$${_envvar_prefix}_PASSWORD not set"

## Identity resolving

if [[ $_is_git == 1 ]] && [[ $_command == "release" ]]; then
    atfile.say.debug "Using release credentials..."

    _fmt_blob_url="$_fmt_blob_url_default"
    _password="$_dist_password"
    _username="$_dist_username"
fi

if [[ -z "$_server" ]]; then
    skip_resolving=0
    
    if [[ $_is_sourced == 0 ]]; then
        # NOTE: Speeds things up a little if the user is overriding actor
        #       Keep this in-sync with the main command case below!
        if [[ $_command == "cat" && -n "$3" ]] ||\
           [[ $_command == "fetch" && -n "$3" ]] ||\
           [[ $_command == "fetch-crypt" && -n "$3" ]] ||\
           [[ $_command == "info" && -n "$2" ]] ||\
           [[ $_command == "list" ]] && [[ "$2" == *.* || "$2" == did:* ]] ||\
           [[ $_command == "list" && -n "$3" ]] ||\
           [[ $_command == "url" && -n "$3" ]]; then
            atfile.say.debug "Skipping identity resolving\n↳ Actor is overridden"
            skip_resolving=1 
        fi

        # NOTE: Speeds things up a little if the command doesn't need actor resolving
        if [[ $_command == "at:"* ]] ||\
           [[ $_command == "atfile:"* ]] ||\
           [[ $_command == "handle" ]] ||\
           [[ $_command == "resolve" ]] ||\
           [[ $_command == "something-broke" ]]; then
            atfile.say.debug "Skipping identity resolving\n↳ Not required for command '$_command'"
            skip_resolving=1
        fi
    fi
    
    if [[ $skip_resolving == 0 ]]; then
        atfile.say.debug "Resolving identity..."

        resolved_id="$(atfile.util.resolve_identity "$_username")"
        _username="$(echo $resolved_id | cut -d "|" -f 1)"
        _server="$(echo $resolved_id | cut -d "|" -f 2)"
        
        atfile.say.debug "Resolved identity\n↳ DID: $_username\n↳ PDS: $_server"
    fi
else
    atfile.say.debug "Skipping identity resolving\n↳ ${_envvar_prefix}_ENDPOINT_PDS is set ($_server)"
    [[ $_server != "http://"* ]] && [[ $_server != "https://"* ]] && _server="https://$_server"
fi

if [[ -n $_server ]]; then
    if [[ $_skip_auth_check == 0 ]]; then
        atfile.say.debug "Checking authentication is valid..."
        
        session="$(com.atproto.server.getSession)"
        if [[ $(atfile.util.is_xrpc_success $? "$session") == 0 ]]; then
            atfile.die "Unable to authenticate"
        else
            _username="$(echo $session | jq -r ".did")"
        fi
    else
        atfile.say.debug "Skipping checking authentication validity\n↳ ${_envvar_prefix}_SKIP_AUTH_CHECK is set ($_skip_auth_check)"
        if [[ "$_username" != "did:"* ]]; then
            atfile.die "Cannot skip authentication validation without a DID\n↳ \$${_envvar_prefix}_USERNAME currently set to '$_username' (need \"did:<type>:<key>\")"
        fi
    fi
fi

## Protocol handling

if [[ "$_command" == "atfile:"* || "$_command" == "at:"* || "$_command" == "https:"* ]]; then
    set -- "handle" "$_command"
    _command="handle"
fi

## Commands

if [[ $_is_sourced == 0 ]]; then
    atfile.say.debug "Running '$_command_full'...\n↳ Command: $_command\n↳ Arguments: ${@:2}"

    case "$_command" in
        "blob")
            case "$2" in
                "list"|"ls"|"l") atfile.invoke.blob_list "$3" ;;
                "upload"|"u") atfile.invoke.blob_upload "$3" ;;
                *) atfile.die.unknown_command "$(echo "$_command $2" | xargs)" ;;
            esac  
            ;;
        "cat")
            [[ -z "$2" ]] && atfile.die "<key> not set"
            if [[ -n "$3" ]]; then
                atfile.util.override_actor "$3"
                atfile.util.print_override_actor_debug
            fi
            
            atfile.invoke.print "$2"
            ;;
        "delete")
            [[ -z "$2" ]] && atfile.die "<key> not set"
            atfile.invoke.delete "$2"
            ;;
        "fetch")
            [[ -z "$2" ]] && atfile.die "<key> not set"
            if [[ -n "$3" ]]; then
                atfile.util.override_actor "$3"
                atfile.util.print_override_actor_debug
            fi
            
            atfile.invoke.download "$2"
            ;;
        "fetch-crypt")
            atfile.util.check_prog_gpg
            [[ -z "$2" ]] && atfile.die "<key> not set"
            if [[ -n "$3" ]]; then
                atfile.util.override_actor "$3"
                atfile.util.print_override_actor_debug
            fi
            
            atfile.invoke.download "$2" 1
            ;;
        "handle")
            uri="$2"
            protocol="$(atfile.util.get_uri_segment $uri protocol)"

            if [[ $protocol == "https" ]]; then
                http_uri="$uri"
                uri="$(atfile.util.map_http_to_at "$http_uri")"

                atfile.say.debug "Mapping '$http_uri'..."
                
                if [[ -z "$uri" ]]; then
                    atfile.die "Unable to map '$http_uri' to at:// URI"
                else
                    protocol="$(atfile.util.get_uri_segment $uri protocol)"
                fi
            fi

            atfile.say.debug "Handling protocol '$protocol://'..."

            case $protocol in
                "at") atfile.invoke.handle_aturi "$uri" ;;
                "atfile") atfile.invoke.handle_atfile "$uri" "$3" ;;
            esac
            ;;
        "info")
            [[ -z "$2" ]] && atfile.die "<key> not set"
            if [[ -n "$3" ]]; then
                atfile.util.override_actor "$3"
                atfile.util.print_override_actor_debug
            fi
            
            atfile.invoke.get "$2"
            ;;
        "list")
            if [[ "$2" == *.* || "$2" == did:* ]]; then
                # NOTE: User has entered <actor> in the wrong place, so we'll fix it
                #       for them
                # BUG:  Keys with periods in them can't be used as a cursor
                
                atfile.util.override_actor "$2"
                atfile.util.print_override_actor_debug

                atfile.invoke.list "$3"
            else
                if [[ -n "$3" ]]; then
                    atfile.util.override_actor "$3"
                    atfile.util.print_override_actor_debug
                fi
                atfile.invoke.list "$2"   
            fi
            ;;
        "lock")
            atfile.invoke.lock "$2" 1
            ;;
        "nick")
            atfile.invoke.profile "$2"
            ;;
        "record")
            # NOTE: Performs no validation (apart from JSON)! Here be dragons
            case "$2" in
                "add"|"create"|"c") atfile.invoke.manage_record "create" "$3" "$4" ;;
                "get"|"g") atfile.invoke.manage_record "get" "$3" "$4" "$5" ;;
                "put"|"update"|"u") atfile.invoke.manage_record "put" "$3" "$4" ;;
                "rm"|"delete"|"d") atfile.invoke.manage_record "delete" "$3" "$4" ;;
                *) atfile.die.unknown_command "$(echo "$_command $2" | xargs)" ;;
            esac
            ;;
        "release")
            atfile.invoke.release
            ;;
        "resolve")
            atfile.invoke.resolve "$2"
            ;;
        "something-broke")
            atfile.invoke.debug
            ;;
        "stream")
            atfile.invoke.stream "$2"
            ;;
        "toggle-mime")
            atfile.invoke.toggle_desktop
            ;;
        "upload")
            atfile.util.check_prog_optional_metadata
            [[ -z "$2" ]] && atfile.die "<file> not set"
            atfile.invoke.upload "$2" "" "$3"
            ;;
        "upload-crypt")
            atfile.util.check_prog_optional_metadata
            atfile.util.check_prog_gpg
            [[ -z "$2" ]] && atfile.die "<file> not set"
            [[ -z "$3" ]] && atfile.die "<recipient> not set"
            atfile.invoke.upload "$2" "$3" "$4"
            ;;
        "unlock")
            atfile.invoke.lock "$2" 0
            ;;
        "url")
            [[ -z "$2" ]] && atfile.die "<key> not set"
            if [[ -n "$3" ]]; then
                atfile.util.override_actor "$3"
                atfile.util.print_override_actor_debug
            fi
            
            atfile.invoke.get_url "$2"
            ;;
        *)
            atfile.die.unknown_command "$_command"
            ;;
    esac
fi

# lord help me
