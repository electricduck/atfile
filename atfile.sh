#!/usr/bin/env bash

# ATFile <https://github.com/electricduck/atfile>

_version="0.2"
_c_year="2024"

# Utilities

function die() {
    echo -e "\033[1;31mError: $1\033[0m"
    exit 255
}

function die_unknown_command() {
    command="$1"
    die "Unknown command '$1'"
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

function check_prog_gpg() {
    check_prog "gpg" "https://gnupg.org/download"
}

function check_prog_optional_metadata() {
    [[ $_skip_ni_exiftool == 0 ]] && check_prog "exiftool" "https://exiftool.org/"
    [[ $_skip_ni_mediainfo == 0 ]] && check_prog "mediainfo" "https://mediaarea.net/en/MediaInfo"
}

function get_blob_uri() {
    did="$1"
    cid="$2"
    pds="$_server"

    echo "$_fmt_blob_url" | sed -e "s|\[pds\]|$pds|g" -e "s|\[server\]|$pds|g"  -e "s|\[cid\]|$cid|g" -e "s|\[did\]|$did|g"
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

function get_date_json() {
    date="$1"
    parsed="$2"

    if [[ -z "$parsed" ]]; then
        if [[ -n "$date" ]]; then
            parsed_date="$(get_date "$date")"
            [[ $? == 0 ]] && parsed="$parsed_date"
        fi
    fi

    if [[ -n "$parsed" ]]; then
        echo "\"$parsed\""
    else
        echo "null"
    fi
}

function get_envvar() {
    envvar="$1"
    default="$2"
    envvar_from_envfile="$(get_envvar_from_envfile "$envvar")"
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

function get_envvar_from_envfile() {
    variable="$1"
    get_var "$_envfile" "$variable"
}

function get_exiftool_field() {
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

function get_file_name_pretty() {
    file_record="$1"
    emoji="$(get_file_type_emoji "$(echo "$file_record" | jq -r '.file.mimeType')")"
    file_name_no_ext="$(echo "$file_record" | jq -r ".file.name" | cut -d "." -f 1)"
    output="$file_name_no_ext"
    
    meta_type="$(echo "$file_record" | jq -r ".meta.\"\$type\"")"
    
    # TODO: json_is_null_or_empty()
    if [[ -n "$meta_type" ]]; then
        case $meta_type in
            "blue.zio.atfile.meta#audio")
                album="$(echo "$file_record" | jq -r ".meta.tags.album")"
                album_artist="$(echo "$file_record" | jq -r ".meta.tags.album_artist")"
                date="$(echo "$file_record" | jq -r ".meta.tags.date.parsed")"
                disc="$(echo "$file_record" | jq -r ".meta.tags.disc.position")"
                title="$(echo "$file_record" | jq -r ".meta.tags.title")"
                track="$(echo "$file_record" | jq -r ".meta.tags.track.position")"
                
                [[ $(is_null_or_empty "$album") == 1 ]] && album="(Unknown Album)"
                [[ $(is_null_or_empty "$album_artist") == 1 ]] && album_artist="(Unknown Artist)"
                [[ $(is_null_or_empty "$disc") == 1 ]] && disc=0
                [[ $(is_null_or_empty "$title") == 1 ]] && title="$file_name_no_ext"
                [[ $(is_null_or_empty "$track") == 1 ]] && track=0
                
                output="$title\n   $album_artist — $album"
                [[ $(is_null_or_empty "$date") == 0 ]] && output+=" ($(date --date="$date" +%Y))"
                [[ $disc != 0 || $track != 0 ]] && output+=" [$disc.$track]"
                ;;
            "blue.zio.atfile.meta#photo")
                date="$(echo "$file_record" | jq -r ".meta.date.create.parsed")"
                lat="$(echo "$file_record" | jq -r ".meta.gps.lat")"
                long="$(echo "$file_record" | jq -r ".meta.gps.long")"
                title="$(echo "$file_record" | jq -r ".meta.title")"
                
                [[ -z "$title" ]] && title="$file_name_no_ext"
                
                output="$title"
                
                if [[ $(is_null_or_empty "$lat") == 0 && $(is_null_or_empty "$long") == 0 ]]; then
                   output+="\n   $long $lat"
                   
                   if [[ $(is_null_or_empty "$date") == 0 ]]; then
                       output+=" — $(date --date="$date")"
                   fi
                fi
                ;;
            "blue.zio.atfile.meta#video")
                title="$(echo "$file_record" | jq -r ".meta.tags.title")"
                
                [[ $(is_null_or_empty "$title") == 1 ]] && title="$file_name_no_ext"
                
                output="$title"
                ;;
        esac
    fi
    
    output="$emoji $output"
    
    output_last_line="$(echo -e "$output" | tail -n1)"
    output_last_line_length="${#output_last_line}"
    
    echo -e "$output"
    echo -e "$(repeat "-" $output_last_line_length)"
}

function get_file_size_pretty() {
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

function get_file_type_emoji() {
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

function get_finger_record() {
    echo -e "$(blue.zio.atfile.finger__machine)"
}

function get_mediainfo_field() {
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

function get_mediainfo_audio_json() {
    file="$1"

    bitRates=$(get_mediainfo_field "$file" "Audio" "BitRate" 0)
    bitRate_modes=$(get_mediainfo_field "$file" "Audio" "BitRate_Mode" "")
    channelss=$(get_mediainfo_field "$file" "Audio" "Channels" 0)
    compressions="$(get_mediainfo_field "$file" "Audio" "Compression_Mode" "")"
    durations=$(get_mediainfo_field "$file" "Audio" "Duration" 0)
    formats="$(get_mediainfo_field "$file" "Audio" "Format" "")"
    format_ids="$(get_mediainfo_field "$file" "Audio" "CodecID" "")"
    format_profiles="$(get_mediainfo_field "$file" "Audio" "Format_Profile" "")"
    samplings=$(get_mediainfo_field "$file" "Audio" "SamplingRate" 0)
    titles="$(get_mediainfo_field "$file" "Audio" "Title" "")"
    
    lines="$(echo "$bitrates" | wc -l)"
    output=""

    for ((i = 0 ; i < $lines ; i++ )); do
        lossy=true
        
        [[ \"$(get_line "$compressionss" $i)\" == "Lossless" ]] && lossy=false
    
        output+="{
    \"bitRate\": $(get_line "$bitRates" $i),
    \"channels\": $(get_line "$channelss" $i),
    \"duration\": $(get_line "$durations" $i),
    \"format\": {
        \"id\": \"$(get_line "$format_ids" $i)\",
        \"name\": \"$(get_line "$formats" $i)\",
        \"profile\": \"$(get_line "$format_profiles" $i)\"
    },
    \"mode\": \"$(get_line "$bitrate_modes" $i)\",
    \"lossy\": $lossy,
    \"sampling\": $(get_line "$samplings" $i),
    \"title\": \"$(get_line "$titles" $i)\"
},"
    done
    
    echo "${output::-1}"
}

function get_mediainfo_video_json() {
    file="$1"

    bitRates=$(get_mediainfo_field "$file" "Video" "BitRate" 0)
    dim_height=$(get_mediainfo_field "$file" "Video" "Height" 0)
    dim_width=$(get_mediainfo_field "$file" "Video" "Width" 0)
    durations=$(get_mediainfo_field "$file" "Video" "Duration" 0)
    formats="$(get_mediainfo_field "$file" "Video" "Format" "")"
    format_ids="$(get_mediainfo_field "$file" "Video" "CodecID" "")"
    format_profiles="$(get_mediainfo_field "$file" "Video" "Format_Profile" "")"
    frameRates="$(get_mediainfo_field "$file" "Video" "FrameRate" "")"
    frameRate_modes="$(get_mediainfo_field "$file" "Video" "FrameRate_Mode" "")"
    titles="$(get_mediainfo_field "$file" "Video" "Title" "")"
    
    lines="$(echo "$bitrates" | wc -l)"
    output=""

    for ((i = 0 ; i < $lines ; i++ )); do    
        output+="{
    \"bitRate\": $(get_line "$bitRates" $i),
    \"dimensions\": {
        \"height\": $dim_height,
        \"width\": $dim_width
    },
    \"duration\": $(get_line "$durations" $i),
    \"format\": {
        \"id\": \"$(get_line "$format_ids" $i)\",
        \"name\": \"$(get_line "$formats" $i)\",
        \"profile\": \"$(get_line "$format_profiles" $i)\"
    },
    \"frameRate\": $(get_line "$frameRates" $i),
    \"mode\": \"$(get_line "$frameRate_modes" $i)\",
    \"title\": \"$(get_line "$titles" $i)\"
},"
    done
    
    echo "${output::-1}"
}

function get_meta_record() {
    file="$1"
    type="$2"
    
    case "$type" in
        "audio/"*) blue.zio.atfile.meta__audio "$1" ;;
        "image/"*) blue.zio.atfile.meta__photo "$1" ;;
        "video/"*) blue.zio.atfile.meta__video "$1" ;;
        *) blue.zio.atfile.meta__unknown "" "$type" ;;
    esac
}

function get_md5() {
    file="$1"
    
    hash="$(md5sum "$file" | cut -f 1 -d " ")"
    if [[ ${#hash} == 32 ]]; then
        echo "$hash"
    fi
}

function get_rkey_from_at_uri() {
    at_uri="$1"
    echo $at_uri | cut -d "/" -f 5
}

function get_term_rows() {
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

function get_var() {
    file="$1"

    if [[ -f "$file" ]]; then
        variable="$2"
        found_line="$(cat "$file" | grep "\b${variable}=")"
        
        if [[ -n "$found_line" ]] && [[ ! "$found_line" == \#* ]]; then
            output="$(echo $found_line | sed "s|${variable}=||g")"
            output="${output%\"}"
            output="${output#\"}"
            
            echo "$output"
        fi
    fi
}

function is_null_or_empty() {
    if [[ -z "$1" ]] || [[ "$1" == null ]]; then
        echo 1
    else
        echo 0
    fi
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
            
            # TODO: Maybe store blob URL format of choice on a record?
            if [[ "$_fmt_blob_url" != "$_fmt_blob_url_default" ]]; then
                export _fmt_blob_url="$_fmt_blob_url_default"
            fi
        fi
    else
        die "Unable to resolve '$actor'"
    fi
}

function print_copyright_warning() {
    if [[ $_skip_copyright_warn == 0 ]]; then
        echo "
 ##########################################
 # You are uploading files to bsky.social #
 #    Do not upload copyrighted files!    #
 ##########################################
"
    fi
}

function print_hidden_command_warning() {
    envvar="$1"
    echo -e "⚠️  Hidden command ($_command)\n   If you know what you're doing, enable with ${_envvar_prefix}_${envvar}=1"
}

function print_table_paginate_hint() {
    cursor="$1"
    count="$2"
    
    if [[ -z $count ]] || (( ( $record_count + $_max_list_buffer ) >= $_max_list )); then
        first_line="List is limited to $_max_list results. To print more results,"
        first_line_length=$(( ${#first_line} + 3 ))
        echo -e "$(repeat "-" $first_line_length)\nℹ️  $first_line\n   run \`$_prog $_command $cursor\`"
    fi
}

function repeat() {
    char="$1"
    amount="$2"
    
    printf "%0.s$char" $(seq 1 $amount)
}

function parse_exiftool_date() {
    in_date="$1"
    tz="$2"
        
    date="$(echo "$in_date" | cut -d " " -f 1 | sed -e "s|:|-|g")"
    time="$(echo "$in_date" | cut -d " " -f 2)"
      
    echo "$date $time $tz"
}

# XRPC

function xrpc_jwt() {
    curl -s -X POST $_server/xrpc/com.atproto.server.createSession \
        -H "Content-Type: application/json" \
        -H "User-Agent: $_uas" \
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
        -H "User-Agent: $_uas" \ | jq
}

function xrpc_post() {
    lexi="$1"
    data="$2"
    type="$3"

    [[ -z $type ]] && type="application/json"

    curl -s -X POST $_server/xrpc/$lexi \
        -H "Authorization: Bearer $(xrpc_jwt)" \
        -H "Content-Type: $type" \
        -H "User-Agent: $_uas" \
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
        -H "User-Agent: $_uas" \
        --data-binary @"$file" | jq
}

# Lexicons

## Records

function get_line() {
    input="$1"
    index=$(( $2 + 1 ))
    
    echo "$(echo -e "$input" | sed -n "$(( $index ))"p)"
}

function blue.zio.atfile.meta__unknown() {
    reason="$1"
    type="$2"
    
    if [[ -z "$reason" ]]; then
        reason="No metadata available for $type"
    fi

    echo "{
    \"\$type\": \"blue.zio.atfile.meta#unknown\",
    \"reason\": \"$reason\"
}"
}

function blue.zio.atfile.meta__audio() {
    file="$1"
    
    if [ ! -x "$(command -v mediainfo)" ]; then
        echo "$(blue.zio.atfile.meta__unknown "Unable to create record at time of upload (MediaInfo not installed)")"
        return
    fi
    
    audio="$(get_mediainfo_audio_json "$file")"
    duration=$(get_mediainfo_field "$file" "General" "Duration" null)
    format="$(get_mediainfo_field "$file" "General" "Format")"
    tag_album="$(get_mediainfo_field "$file" "General" "Album")"
    tag_albumArtist="$(get_mediainfo_field "$file" "General" "Album/Performer")"
    tag_artist="$(get_mediainfo_field "$file" "General" "Performer")"
    tag_date="$(get_mediainfo_field "$file" "General" "Original/Released_Date")"
    tag_disc=$(get_mediainfo_field "$file" "General" "Part/Position" null)
    tag_discTotal=$(get_mediainfo_field "$file" "General" "Part/Position_Total" null)
    tag_title="$(get_mediainfo_field "$file" "General" "Title")"
    tag_track=$(get_mediainfo_field "$file" "General" "Track/Position" null)
    tag_trackTotal=$(get_mediainfo_field "$file" "General" "Track/Position_Total" null)
    
    parsed_tag_date=""
    
    if [[ "${#tag_date}" > 4 ]]; then
        parsed_tag_date="$(get_date "$tag_date")"
    elif [[ "${#tag_date}" == 4 ]]; then
        parsed_tag_date="$(get_date "${tag_date}-01-01")"
    fi
    
    echo "{
    \"\$type\": \"blue.zio.atfile.meta#audio\",
    \"audio\": [ $audio ],
    \"duration\": $duration,
    \"format\": \"$format\",
    \"tags\": {
        \"album\": \"$tag_album\",
        \"album_artist\": \"$tag_albumArtist\",
        \"artist\": \"$tag_artist\",
        \"date\": $(get_date_json "$tag_date" "$parsed_tag_date"),
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

    artist="$(get_exiftool_field "$file" "Artist")"
    camera_aperture="$(get_exiftool_field "$file" "Aperture")"
    camera_exposure="$(get_exiftool_field "$file" "ExposureTime")"
    camera_flash="$(get_exiftool_field "$file" "Flash")"
    camera_focalLength="$(get_exiftool_field "$file" "FocalLength")"
    camera_iso="$(get_exiftool_field "$file" "ISO" null)"
    camera_make="$(get_exiftool_field "$file" "Make")"
    camera_mpx="$(get_exiftool_field "$file" "Megapixels" null)"
    camera_model="$(get_exiftool_field "$file" "Model")"
    date_create="$(get_exiftool_field "$file" "CreateDate")"
    date_modify="$(get_exiftool_field "$file" "ModifyDate")"
    date_tz="$(get_exiftool_field "$file" "OffsetTime" "+00:00")"
    dim_height="$(get_exiftool_field "$file" "ImageHeight" null)"
    dim_width="$(get_exiftool_field "$file" "ImageWidth" null)"
    gps_alt="$(get_exiftool_field "$file" "GPSAltitude" null)"
    gps_lat="$(get_exiftool_field "$file" "GPSLatitude" null)"
    gps_long="$(get_exiftool_field "$file" "GPSLongitude" null)"
    orientation="$(get_exiftool_field "$file" "Orientation")"
    software="$(get_exiftool_field "$file" "Software")"
    title="$(get_exiftool_field "$file" "Title")"
    
    date_create="$(parse_exiftool_date "$date_create" "$date_tz")"
    date_modify="$(parse_exiftool_date "$date_modify" "$date_tz")"
    
    [[ $gps_alt == +* ]] && gps_alt="${gps_alt:1}"
    [[ $gps_lat == +* ]] && gps_lat="${gps_lat:1}"
    [[ $gps_long == +* ]] && gps_long="${gps_long:1}"

    echo "{
    \"\$type\": \"blue.zio.atfile.meta#photo\",
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
        \"create\": $(get_date_json "$date_create"),
        \"modify\": $(get_date_json "$date_modify")
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
    
    artist="$(get_mediainfo_field "$file" "General" "Artist")"
    audio="$(get_mediainfo_audio_json "$file")"
    bitRate=$(get_mediainfo_field "$file" "General" "BitRate" null)
    date_create="",
    date_modify="",
    duration=$(get_mediainfo_field "$file" "General" "Duration" null)
    format="$(get_mediainfo_field "$file" "General" "Format")"
    gps_alt=0
    gps_lat=0
    gps_long=0
    title="$(get_mediainfo_field "$file" "General" "Title")"
    video="$(get_mediainfo_video_json "$file")"
    
    if [ -x "$(command -v exiftool)" ]; then
        date_create="$(get_exiftool_field "$file" "CreateDate")"
        date_modify="$(get_exiftool_field "$file" "ModifyDate")"
        date_tz="$(get_exiftool_field "$file" "OffsetTime" "+00:00")"
        gps_alt="$(get_exiftool_field "$file" "GPSAltitude" null)"
        gps_lat="$(get_exiftool_field "$file" "GPSLatitude" null)"
        gps_long="$(get_exiftool_field "$file" "GPSLongitude" null)"
        
        date_create="$(parse_exiftool_date "$date_create" "$date_tz")"
        date_modify="$(parse_exiftool_date "$date_modify" "$date_tz")"
    fi
    
    echo "{
    \"\$type\": \"blue.zio.atfile.meta#video\",
    \"artist\": \"$artist\",
    \"audio\": [ $audio ],
    \"biteRate\": $bitRate,
    \"date\": {
        \"create\": $(get_date_json "$date_create"),
        \"modify\": $(get_date_json "$date_modify")
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
    id="$1"
    userAgent="$2"

    echo "{
    \"\$type\": \"blue.zio.atfile.finger#browser\",
    \"id\": \"$id\",
    \"userAgent\": \"$userAgent\"
}"
}

function blue.zio.atfile.finger__machine() {
    machine_id_file="/etc/machine-id"
    os_release_file="/etc/os-release"
    
    [[ ! -f "$machine_id_file" ]] && die "Unable to fingerprint — '$machine_id_file' does not exist"
    [[ ! -f "$os_release_file" ]] && die "Unable to fingerprint — '$os_release_file' does not exist"
    
    id="$(cat "$machine_id_file")"
    hostname="$(hostname -s)"
    os_name="$(get_var "$os_release_file" "NAME")"
    os_version="$(get_var "$os_release_file" "VERSION")"
    os="$os_name $os_version"
    
    echo "{
    \"\$type\": \"blue.zio.atfile.finger#machine\",
    \"id\": \"$id\",
    \"host\": \"$hostname\",
    \"os\": \"$os\"
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
        \"modifiedAt\": \"$file_modifiedAt\",
        \"mimeType\": \"$file_type\",
        \"name\": \"$file_name\",
        \"size\": $file_size
    },
    \"checksum\": {
        \"hash\": \"$file_hash\",
        \"type\": \"$file_hash_type\"
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

function invoke_manage_record() {
    function get_collection() {
        collection="blue.zio.atfile.upload"
        parameter_output="$1"
        [[ -n "$1" ]] && collection="$1" # fuck it, manage all the records from atfile!
        echo "$collection"
    }
    
    case "$1" in
        "create")
            collection="$(get_collection "$3")"
            record="$2"
            [[ -z "$record" ]] && die "<record> not set"
            
            record_json="$(echo "$record" | jq)"
            [[ $? != 0 ]] && die "Invalid JSON"
            
            com.atproto.repo.createRecord "$_username" "$collection" "$record_json" | jq
            ;;
        "delete")
            collection="$(get_collection "$3")"
            key="$2"
            [[ -z "$key" ]] && die "<key> not set"
            
            if [[ "$key" == at:* ]]; then
                at_uri="$key"
                collection="$(echo $at_uri | cut -d "/" -f 4)"
                key="$(echo $at_uri | cut -d "/" -f 5)"
                username="$(echo $at_uri | cut -d "/" -f 3)"
                
                [[ "$username" != "$_username" ]] && die "Unable to delete record — not owned by you ($_username)"
            fi
            
            com.atproto.repo.deleteRecord "$_username" "$collection" "$key" | jq
            ;;
        "get")
            collection="$(get_collection "$3")"
            key="$2"
            username="$4"
            [[ -z "$key" ]] && die "<key/at-uri> not set"
            
            if [[ "$key" == at:* ]]; then
                at_uri="$key"
                collection="$(echo $at_uri | cut -d "/" -f 4)"
                key="$(echo $at_uri | cut -d "/" -f 5)"
                username="$(echo $at_uri | cut -d "/" -f 3)"
            fi
            
            if [[ -z "$username" ]]; then
                username="$_username"
            else
                override_actor "$username"
            fi
            
            com.atproto.repo.getRecord "$username" "$collection" "$key" | jq
            ;;
        "put")
            collection="$(get_collection "$3")"
            key="$2"
            record="$3"
            [[ -z "$key" ]] && die "<key> not set"
            [[ -z "$record" ]] && die "<record> not set"
            
            record_json="$(echo "$record" | jq)"
            [[ $? != 0 ]] && die "Invalid JSON"
            
            com.atproto.repo.putRecord "$_username" "$collection" "$key" "$record" | jq
            ;;
    esac
}

function invoke_delete() {
    key="$1"
    success=1

    lock_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.lock" "$key")"

    if [[ $(is_xrpc_success $? "$lock_record") == 1 ]] && [[ $(echo "$lock_record" | jq -r ".value.lock") == true ]]; then
        die "Unable to delete '$key' — file is locked\n       Run \`$_prog unlock $key\` to unlock file"
    fi

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
        
        curl -H "User-Agent: $_uas" --silent "$blob_uri" -o "$downloaded_file"
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
    	file_hash_pretty="$file_hash ($file_hash_type)"
        file_name="$(echo "$record" | jq -r '.value.file.name')"
        file_name_pretty="$(get_file_name_pretty "$(echo "$record" | jq -r '.value')")"
        file_size="$(echo "$record" | jq -r '.value.file.size')"
        file_size_pretty="$(get_file_size_pretty $file_size)"
        file_type="$(echo "$record" | jq -r '.value.file.mimeType')"
        
        did="$(echo $record | jq -r ".uri" | cut -d "/" -f 3)"
        key="$(get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        blob_uri="$(get_blob_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")")"
        cdn_uri="$(get_cdn_uri "$did" "$(echo $record | jq -r ".value.blob.ref.\"\$link\"")" "$file_type")"
        encrypted="No"
        locked="No"
        finger="(None)"
        finger_type=""
        header="$file_name_pretty"
        
        if [[ $(is_null_or_empty "$file_hash_type") == 1 ]] || [[ "$file_hash_type" == "md5" && ${#file_hash} != 32 ]] || [[ "$file_hash_type" == "none" ]]; then
            file_hash_pretty="(None)"
        fi
        
        if [[ "$file_type" == "application/prs.atfile.gpg-crypt" ]]; then
            encrypted="Yes"
        fi
        
        locked_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.lock" "$key")"
        if [[ $? == 0 ]] && [[ -n "$locked_record" ]]; then
            if [[ $(echo $locked_record | jq -r ".value.lock") == true ]]; then
                locked="Yes"
            fi
        fi
        
        if [[ "$(echo $record | jq -r ".value.finger")" != "null" ]]; then
            finger_type="$(echo $record | jq -r ".value.finger.\"\$type\"" | cut -d "#" -f 2)"
            finger="$(echo $record | jq -r ".value.finger.id")"
        fi
        
        echo "$header"
        echo -e "↳ Blob: $blob_uri"
        [[ -n "$cdn_uri" ]] && echo -e " ↳ CDN: $cdn_uri"
        echo -e "↳ File: $key"
        echo -e " ↳ Name: $file_name"
        echo -e " ↳ Type: $file_type"
        echo -e " ↳ Size: $file_size_pretty"
        echo -e " ↳ Date: $(date --date "$file_date" "+%Y-%m-%d %H:%M:%S %Z")"
        echo -e " ↳ Hash: $file_hash_pretty"
        echo -e "↳ Locked: $locked"
        echo -e "↳ Encrypted: $encrypted"
        echo -e "↳ Finger: $finger"
        case $finger_type in
            "browser")
                echo -e " ↳ Hostname: $(echo $record | jq -r ".value.finger.userAgent")"
                ;;
            "machine")
                echo -e " ↳ Hostname: $(echo $record | jq -r ".value.finger.host")"
                echo -e " ↳ OS: $(echo $record | jq -r ".value.finger.os")"
                ;;
        esac
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
   
    if [[ $success == 1 ]]; then
    	records="$(echo $records | jq -c '.records[]')"
        [[ -z "$records" ]] && die "No files for '$_username'"
        
        unset last_key
        unset record_count
    
        echo -e "Key\t\tFile"
        echo -e "---\t\t----"
        
        while IFS=$"\n" read -r c; do
            key=$(get_rkey_from_at_uri "$(echo $c | jq -r ".uri")")
            name="$(echo "$c" | jq -r '.value.file.name')"
            type_emoji="$(get_file_type_emoji "$(echo "$c" | jq -r '.value.file.mimeType')")"
            last_key="$key"
            ((record_count++))

            if [[ -n $key ]]; then
                echo -e "$key\t$type_emoji $name"
            fi
        done <<< "$records"
         
        print_table_paginate_hint "$last_key" $record_count
    else
        die "Unable to list files"
    fi
}

function invoke_list_blobs() {
    cursor="$1"
    success=1
    
    blobs="$(com.atproto.sync.listBlobs "$_username" "$cursor")"
    success="$(is_xrpc_success $? "$blobs")"

    if [[ $success == 1 ]]; then
    	records="$(echo $blobs | jq -c '.cids[]')"
    	[[ -z "$records" ]] && die "No blobs for '$_username'"
    
    	unset last_cid
        unset record_count
    
        echo -e "URL"
        echo -e "---"
    
        while IFS=$"\n" read -r c; do
            cid="$(echo $c | jq -r ".")"
            last_cid="$cid"
            ((record_count++))
            
            echo "$(get_blob_uri "$_username" "$cid")"
        done <<< "$records"
        
        print_table_paginate_hint "$last_cid" $record_count
    else
        die "Unable to list blobs"
    fi
}

function invoke_lock() {
    key="$1"
    locked=$2
    
    upload_record="$(com.atproto.repo.getRecord "$_username" "blue.zio.atfile.upload" "$key")"
    success=$(is_xrpc_success $? "$upload_record")
    
    if [[ $success == 1 ]]; then        
        if [[ $locked == 1 ]]; then
            locked=true
        else
            locked=false
        fi
        
        lock_record="$(blue.zio.atfile.lock $locked)"
        record="$(com.atproto.repo.putRecord "$_username" "blue.zio.atfile.lock" "$key" "$lock_record")"
        success=$(is_xrpc_success $? "$record")
    fi
    
    if [[ $(is_xrpc_success $? "$record") == 1 ]]; then
        if [[ $locked == true ]]; then
            echo "Locked: $key"
        else
            echo "Unlocked: $key"
        fi
    else
         if [[ $locked == true ]]; then
            die "Unable to lock '$key'"
        else
            die "Unable to unlock '$key'"
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
        
        curl -H "$_uas" -s -L "$blob_uri" --output -
        [[ $? != 0 ]] && success=0
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
    
    if [[ "$_server" == "https://bsky.social" ]]; then
        print_copyright_warning
    fi
    
    if [[ -n $recipient ]]; then
        file_crypt="$(dirname "$file")/$(basename "$file").gpg"
        
        echo -e "Encrypting '$file_crypt'..."
        gpg --yes --quiet --recipient $recipient --output "$file_crypt" --encrypt "$file"
        [[ $? != 0 ]] && success=0
        
        if [[ $success == 1 ]]; then
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
        
        file_type_emoji="$(get_file_type_emoji "$file_type")"
        
        unset file_finger_record
        unset file_meta_record
        
        [[ $_fingerprint == 1 ]] && file_finger_record="$(get_finger_record)"
        file_meta_record="$(get_meta_record "$file" "$file_type")"
        
        echo "Uploading '$file'..."
        blob="$(com.atproto.sync.uploadBlob "$file")"
        success=$(is_xrpc_success $? "$blob")
        
        file_record="$(blue.zio.atfile.upload "$blob" "$_now" "$file_hash" "$file_hash_type" "$file_date" "$file_name" "$file_size" "$file_type" "$file_meta_record" "$file_finger_record")"
        
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
        echo "---"
        echo "Uploaded: $file_type_emoji $file_name"
        echo -e "↳ Blob: $(get_blob_uri "$(echo $record | jq -r ".uri" | cut -d "/" -f 3)" "$(echo $blob | jq -r ".ref.\"\$link\"")")"
        echo -e "↳ Key: $(get_rkey_from_at_uri "$(echo $record | jq -r ".uri")")"
        if [[ -n "$recipient" ]]; then
            echo -e "↳ Recipient: $recipient ($(gpg --list-keys $recipient | sed -n 2p | xargs))"
        fi
    else
        die "Unable to upload '$file'"
    fi
}

function invoke_print_vars() {
    function print_envvar() {
        variable_name="${_envvar_prefix}_$1"
        variable_default="$2"
        
        unset output
        
        output="$variable_name: $(get_envvar "$variable_name" "$variable_default")"
        [[ -n "$variable_default" ]] && output+=" ($variable_default)"
        
        echo -e "$output"
    }
    
    print_envvar "USERNAME"
    echo "$(print_envvar "PASSWORD" | cut -d ":" -f 1): $(print_envvar "PASSWORD" | cut -d ":" -f 2 | xargs | sed -e "s/./\*/g")"
    print_envvar "PDS" "$_server_default"
    print_envvar "ENABLE_RECORD_COMMAND" "$_hidden_command_record"
    print_envvar "FINGERPRINT" "$_fingerprint_default"
    print_envvar "FMT_BLOB_URL" "$_fmt_blob_url_default"
    print_envvar "MAX_LIST" "$_max_list_default"
    print_envvar "SKIP_AUTH_CHECK" "$_skip_auth_check_default"
    print_envvar "SKIP_COPYRIGHT_WARN" "$_skip_copyright_warn_default"
    print_envvar "SKIP_NI_EXIFTOOL" "$_skip_ni_exiftool_default"
    print_envvar "SKIP_NI_MEDIAINFO" "$_skip_ni_mediainfo_default"
}

function invoke_usage() {
# ------------------------------------------------------------------------------
    echo -e "ATFile | 📦 ➔ 🦋
    Store and retrieve files on a PDS
    
    Version $_version
    (c) $_c_year Ducky <https://github.com/electricduck/atfile>
    Licensed under MIT License ✨
    
Commands
    upload <file> [<key>]
        Upload new file to the PDS
        ⚠️  ATProto records are public: do not upload sensitive files
        
    list [<cursor>] [<actor>]
    list <actor> [<cursor>]
        List all uploaded files. Only $_max_list items can be displayed; to
        paginate, use the last Key for <cursor>

    fetch <key> [<out-dir>] [<actor>]
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
           safety-net in the case of inadvertently deleting the wrong file

    upload-crypt <file> <recipient> [<key>]
        Encrypt file (with GPG) for <recipient> and upload to the PDS
        ℹ️  Make sure the necessary GPG key has been imported first
        
    fetch-crypt <file> [<actor>]
        Download an uploaded encrypted file and attempt to decrypt it (with GPG)
        ℹ️  Make sure the necessary GPG key has been imported first
        
    nick <nick>
        Set nickname
        ℹ️  Intended for future use
    $([[ $_hidden_command_record == 1 ]] && echo -e "\n    record add <record-json> [<collection>]
    record get <key> [<collection>] [<actor>]
    record get <at-uri>
    record put <key> <record-json> [<collection>]
    record rm <key> [<collection>]
    record rm <at-uri>
        Manage records on a repository
        ⚠️  Intended for advanced users. Here be dragons.
           Turn this feature off with ${_envvar_prefix}_HIDDEN_COMMAND_RECORD=0")
       
Arguments
    <actor>     Act upon another ATProto user (either by handle or DID)
    <cursor>    Key or CID used as a reference to paginate through lists
    <key>       Key of an uploaded file (unique to that user and collection)
    <nick>      Nickname
    <out-dir>   Path to receive downloaded files
    <recipient> GPG recipient during file encryption
                See 'gpg --help' for more information

Environment Variables
    ${_envvar_prefix}_PDS <url> (default: $_server_default)
        Endpoint of the PDS
    ${_envvar_prefix}_USERNAME <string>
        Username of the PDS user (handle or DID)
    ${_envvar_prefix}_PASSWORD <string>
        Password of the PDS user
        An App Password is recommended (https://bsky.app/settings/app-passwords)
    ${_envvar_prefix}_FINGERPRINT <int> (default $_fmt_blob_url_default)
        Apply machine fingerprint to uploaded files
    ${_envvar_prefix}_MAX_LIST <int> (default: $_max_list_default)
        Maximum amount of items in any lists
        Default value is calculated from your terminal's height
    ${_envvar_prefix}_FMT_BLOB_URL <string> (default: $_fmt_blob_url_default)
        Format for blob URLs. See default (above) for example; includes
        all possible fragments
    ${_envvar_prefix}_SKIP_AUTH_CHECK <bool*> (default: $_skip_auth_check_default)
        Skip session validation on startup
        If you're confident your credentials are correct, and \$${_envvar_prefix}_USERNAME
        is a DID (*not* a handle), this will drastically improve performance!
    ${_envvar_prefix}_SKIP_COPYRIGHT_WARN <bool*> (default: $_skip_copyright_warn_default)
        Do not print copyright warning when uploading files to
        https://bsky.social
    ${_envvar_prefix}_SKIP_NI_EXIFTOOL <bool*> (default: $_skip_ni_exiftool_default)
        Do not check if ExifTool is installed
        ⚠️  If Exiftool is not installed, the relevant metadata records will
           not be created:
           * image/*: blue.zio.atfile.meta#photo
    ${_envvar_prefix}_SKIP_NI_MEDIAINFO <bool*> (default: $_skip_ni_mediainfo_default)
        Do not check if MediaInfo is installed
        ⚠️  If MediaInfo is not installed, the relevant metadata records will
           not be created:
           * audio/*: blue.zio.atfile.meta#audio
           * video/*: blue.zio.atfile.meta#video
           
    * A bool in Bash is 1 (true) or 0 (false)

Files
    $_envfile
        List of key/values of the above environment variables. Exporting these
        on the shell (with \`export \$ATFILE_VARIABLE\`) overrides these values
" | less
# ------------------------------------------------------------------------------
}

# Main

_prog="$(basename "$(realpath -s "$0")")"
_now="$(get_date)"

_command="$1"

_envvar_prefix="ATFILE"
_envfile="$HOME/.config/atfile.env"

_fingerprint_default=0
_fmt_blob_url_default="[server]/xrpc/com.sync.atproto.getBlob?did=[did]&cid=[cid]"
_hidden_command_record_default=0
_max_list_buffer=6
_max_list_default=$(( $(get_term_rows) - $_max_list_buffer ))
_server_default="https://bsky.social"
_skip_auth_check_default=0
_skip_copyright_warn_default=0
_skip_ni_exiftool_default=0
_skip_ni_mediainfo_default=0

_fingerprint="$(get_envvar "${_envvar_prefix}_FINGERPRINT" "$_fingerprint_default")"
_fmt_blob_url="$(get_envvar "${_envvar_prefix}_FMT_BLOB_URL" "$_fmt_blob_url_default")"
_hidden_command_record="$(get_envvar "${_envvar_prefix}_HIDDEN_COMMAND_RECORD" "$_hidden_command_record_default")"
_max_list="$(get_envvar "${_envvar_prefix}_MAX_LIST" "$_max_list_default")"
_server="$(get_envvar "${_envvar_prefix}_PDS" "$_server_default")"
_skip_auth_check="$(get_envvar "${_envvar_prefix}_SKIP_AUTH_CHECK" "$_skip_auth_check_default")"
_skip_copyright_warn="$(get_envvar "${_envvar_prefix}_SKIP_COPYRIGHT_WARN" "$_skip_copyright_warn_default")"
_skip_ni_exiftool="$(get_envvar "${_envvar_prefix}_SKIP_NI_EXIFTOOL" "$_skip_ni_exiftool_default")"
_skip_ni_mediainfo="$(get_envvar "${_envvar_prefix}_SKIP_NI_MEDIAINFO" "$_skip_ni_mediainfo_default")"
_password="$(get_envvar "${_envvar_prefix}_PASSWORD")"
_uas="ATFile/$_version"
_username="$(get_envvar "${_envvar_prefix}_USERNAME")"

[[ $(( $_max_list > 100 )) == 1 ]] && _max_list="100"
[[ $_server != "http://"* ]] && [[ $_server != "https://"* ]] && _server="https://$_server"

if [ -x "$(command -v git)" ] && [[ -d "$(dirname "$(realpath -s "$0")")/.git" ]]; then
    _version+="+git.$(git rev-parse --short HEAD)"
fi

if [[ $_command == "" || $_command == "help" || $_command == "h" || $_command == "--help" || $_command == "-h" ]]; then
    invoke_usage
    exit 0
fi

check_prog "curl"
check_prog "jq" "https://jqlang.github.io/jq"
check_prog "md5sum"
check_prog "xargs"

[[ -z "$_username" ]] && die "\$${_envvar_prefix}_USERNAME not set"
[[ -z "$_password" ]] && die "\$${_envvar_prefix}_PASSWORD not set"

if [[ $_command == "test-vars" ]]; then
    invoke_print_vars
    exit 0
fi

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
        check_prog_gpg
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
    	if [[ "$2" == *.* ]]; then
    	    # NOTE: User has entered <actor> in the wrong place, so we'll fix it
    	    #       for them
    	    # BUG:  Keys with periods in them can't be used as a cursor
    	    
    	    override_actor "$2"
            invoke_list "$3"
    	else
    	    [[ -n "$3" ]] && override_actor "$3"
            invoke_list "$2"   
    	fi
        ;;
    "list-blobs"|"lsb")
        invoke_list_blobs "$2"
        ;;
    "lock")
        invoke_lock "$2" 1
        ;;
    "nick")
        invoke_profile "$2"
        ;;
    "record")
        # NOTE: Performs no validation (apart from JSON)! Here be dragons.
        if [[ "$_hidden_command_record" == 1 ]]; then
            case "$2" in
                "add"|"create"|"c") invoke_manage_record "create" "$3" "$4" ;;
                "get"|"g") invoke_manage_record "get" "$3" "$4" "$5" ;;
                "put"|"update"|"u") invoke_manage_record "put" "$3" "$4" ;;
                "rm"|"delete"|"d") invoke_manage_record "delete" "$3" "$4" ;;
                *) die_unknown_command "$(echo "$_command $2" | xargs)" ;;
            esac
        else
            print_hidden_command_warning "ENABLE_RECORD_COMMAND"
            exit 1
        fi
        ;;
    "upload"|"ul"|"u")
        check_prog_optional_metadata
        [[ -z "$2" ]] && die "<file> not set"
        invoke_upload "$2" "" "$3"
        ;;
    "upload-crypt"|"uc")
        check_prog_optional_metadata
        check_prog_gpg
        [[ -z "$2" ]] && die "<file> not set"
        [[ -z "$3" ]] && die "<recipient> not set"
        invoke_upload "$2" "$3" "$4"
        ;;
    "unlock")
        invoke_lock "$2" 0
        ;;
    "url"|"get-url"|"b")
        [[ -z "$2" ]] && die "<key> not set"
        [[ -n "$3" ]] && override_actor "$3"
        invoke_get_url "$2"
        ;;
    "temp-get-finger")
        get_finger_record
        ;;
    "temp-get-meta")
        get_meta_record "$2" "$3"
        ;;
    "temp-get-meta-jq")
        get_meta_record "$2" "$3" | jq
        ;;
    *)
        die_unknown_command "$_command"
        ;;
esac
