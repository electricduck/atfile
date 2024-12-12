#!/usr/bin/env bash

# blue.zio.atfile.*

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

    if [[ $_enable_fingerprint == 1 ]]; then
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
            "linux-termux")
                machine_os="Termux $TERMUX_VERSION"
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
