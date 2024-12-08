#!/usr/bin/env bash

# Entry

## Global variables

### General

_start="$(atfile.util.get_date "" "%s")"
_command="$1"
_command_full="$@"
_envvar_prefix="ATFILE"
_os="$(atfile.util.get_os)"
_is_git=0
_is_sourced=0
_meta_author="{:meta_author:}"
_meta_did="{:meta_did:}"
_meta_repo="{:meta_repo:}"
_meta_year="{:meta_year:}"
_now="$(atfile.util.get_date)"
_version="{:version:}"

### Reflection

_prog="$(basename "$(atfile.util.get_realpath "$0")")"
_prog_dir="$(dirname "$(atfile.util.get_realpath "$0")")"
_prog_path="$(atfile.util.get_realpath "$0")"

### Paths

_path_home="$HOME"

if [[ -n "$SUDO_USER" ]]; then
    _path_home="$(eval echo "~$SUDO_USER")"
fi

_file_envvar="atfile.env"
_path_blobs_tmp="/tmp"
_path_cache="$_path_home/.cache"
_path_envvar="$_path_home/.config"

case $_os in
    "haiku")
        _path_blobs_tmp="/boot/system/cache/tmp"
        _path_cache="$_path_home/config/cache"
        _path_envvar="$_path_home/config/settings"
        ;;
    "linux-termux")
        _path_blobs_tmp="/data/data/com.termux/files/tmp"
        ;;
    "macos")
        _path_blobs_tmp="/private/tmp"
        ;;
esac

_path_blobs_tmp="$_path_blobs_tmp/at-blobs"
_path_cache="$_path_cache/atfile"
_path_envvar="$(atfile.util.get_envvar "${_envvar_prefix}_PATH_CONF" "$_path_envvar/$_file_envvar")" 

### Envvars

#### Defaults

_debug_default=0
_devel_publish_default=0
_disable_updater_default=0
_dist_username_default="$_meta_did"
_endpoint_appview_bsky_default="https://api.bsky.app"
_endpoint_jetstream_default="wss://jetstream.atproto.tools"
_endpoint_resolve_handle_default="https://zio.blue" # lol wtf is bsky.social
_endpoint_plc_directory_default="https://plc.zio.blue"
_fmt_blob_url_default="[server]/xrpc/com.atproto.sync.getBlob?did=[did]&cid=[cid]"
_fmt_out_file_default="[key]__[name]"
_enable_fingerprint_default=0
_max_list_buffer=6
_max_list_default=$(( $(atfile.util.get_term_rows) - $_max_list_buffer ))
_output_json_default=0
_skip_auth_check_default=0
_skip_copyright_warn_default=0
_skip_ni_exiftool_default=0
_skip_ni_md5sum_default=0
_skip_ni_mediainfo_default=0
_skip_unsupported_os_warn_default=0

#### Fallbacks

_endpoint_plc_directory_fallback="https://plc.directory"
_max_list_fallback=100

#### Set

_debug="$(atfile.util.get_envvar "${_envvar_prefix}_DEBUG" $_debug_default)"
_devel_publish="$(atfile.util.get_envvar "${_envvar_prefix}_DEVEL_PUBLISH" $_devel_publish_default)"
_disable_updater="$(atfile.util.get_envvar "${_envvar_prefix}_DISABLE_UPDATER" $_disable_updater_default)"
_dist_password="$(atfile.util.get_envvar "${_envvar_prefix}_DIST_PASSWORD" $_dist_password_default)"
_dist_username="$(atfile.util.get_envvar "${_envvar_prefix}_DIST_USERNAME" $_dist_username_default)"
_enable_fingerprint="$(atfile.util.get_envvar "${_envvar_prefix}_ENABLE_FINGERPRINT" "$_enable_fingerprint_default")"
_endpoint_appview_bsky="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_APPVIEW_BSKY" "$_endpoint_appview_bsky_default")"
_endpoint_jetstream="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_JETSTREAM" "$_endpoint_jetstream_default")"
_endpoint_plc_directory="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_PLC_DIRECTORY" "$_endpoint_plc_directory_default")"
_endpoint_resolve_handle="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_RESOLVE_HANDLE" "$_endpoint_resolve_handle_default")"
_fmt_blob_url="$(atfile.util.get_envvar "${_envvar_prefix}_FMT_BLOB_URL" "$_fmt_blob_url_default")"
_fmt_out_file="$(atfile.util.get_envvar "${_envvar_prefix}_FMT_OUT_FILE" "$_fmt_out_file_default")"
_force_meta_author="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_META_AUTHOR")"
_force_meta_did="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_META_DID")"
_force_meta_repo="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_META_REPO")"
_force_meta_year="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_META_YEAR")"
_force_now="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_NOW")"
_force_os="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_OS")"
_force_version="$(atfile.util.get_envvar "${_envvar_prefix}_FORCE_VERSION")"
_max_list="$(atfile.util.get_envvar "${_envvar_prefix}_MAX_LIST" "$_max_list_default")"
_output_json="$(atfile.util.get_envvar "${_envvar_prefix}_OUTPUT_JSON" "$_output_json_default")"
_server="$(atfile.util.get_envvar "${_envvar_prefix}_ENDPOINT_PDS")"
_skip_auth_check="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_AUTH_CHECK" "$_skip_auth_check_default")"
_skip_copyright_warn="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_COPYRIGHT_WARN" "$_skip_copyright_warn_default")"
_skip_ni_exiftool="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_NI_EXIFTOOL" "$_skip_ni_exiftool_default")"
_skip_ni_md5sum="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_NI_MD5SUM" "$_skip_ni_md5sum_default")"
_skip_ni_mediainfo="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_NI_MEDIAINFO" "$_skip_ni_mediainfo_default")"
_skip_unsupported_os_warn="$(atfile.util.get_envvar "${_envvar_prefix}_SKIP_UNSUPPORTED_OS_WARN" "$_skip_unsupported_os_warn_default")"
_password="$(atfile.util.get_envvar "${_envvar_prefix}_PASSWORD")"
_test_desktop_uas="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
_username="$(atfile.util.get_envvar "${_envvar_prefix}_USERNAME")"

### NSIDs

_nsid_prefix="blue.zio"
_nsid_lock="${_nsid_prefix}.atfile.lock"
_nsid_meta="${_nsid_prefix}.atfile.meta"
_nsid_upload="${_nsid_prefix}.atfile.upload"

## Source detection

if [[ "$0" != "$BASH_SOURCE" ]] && [[ "$ATFILE_DEVEL" != 1 ]]; then
    _debug=0
    _is_sourced=1
    _output_json=1
fi

## "Hello, world!"

atfile.say.debug "Starting up..."

## Envvar correction

### Overrides

[[ -n $_force_meta_author ]] && \
    _meta_author="$_force_meta_author" &&\
    atfile.say.debug "Overriding Copyright Author (\$_meta_author)\n↳ ${_envvar_prefix}_FORCE_META_AUTHOR set to '$_force_meta_author'"
[[ -n $_force_meta_did ]] && \
    _meta_did="$_force_meta_did" &&\
    _dist_username="$(atfile.util.get_envvar "${_envvar_prefix}_DIST_USERNAME" $_meta_did)" &&\
    atfile.say.debug "Overriding DID (\$_meta_did)\n↳ ${_envvar_prefix}_FORCE_META_DID set to '$_force_meta_did'"
[[ -n $_force_meta_repo ]] && \
    _meta_repo="$_force_meta_repo" &&\
    atfile.say.debug "Overriding Repo URL (\$_meta_repo)\n↳ ${_envvar_prefix}_FORCE_META_REPO set to '$_force_meta_repo'"
[[ -n $_force_meta_year ]] && \
    _meta_year="$_force_meta_year" &&\
    atfile.say.debug "Overriding Copyright Year (\$_meta_year)\n↳ ${_envvar_prefix}_FORCE_META_YEAR set to '$_force_meta_year'"
[[ -n $_force_now ]] && \
    _now="$_force_now" &&\
    atfile.say.debug "Overriding Now (\$_now)\n↳ ${_envvar_prefix}_FORCE_NOW set to '$_force_now'"
[[ -n $_force_os ]] &&\
    _os="$_force_os" &&\
    atfile.say.debug "Overriding OS (\$_os)\n↳ ${_envvar_prefix}_FORCE_OS set to '$_force_os'"
[[ -n $_force_version ]] && \
    _version="$_force_version" &&\
    atfile.say.debug "Overriding Version (\$_version)\n↳ ${_envvar_prefix}_FORCE_VERSION set to '$_force_version'"

### Legacy

[[ $_enable_fingerprint == $_enable_fingerprint_default ]] &&\
    _include_fingerprint_depr="$(atfile.util.get_envvar "${_envvar_prefix}_INCLUDE_FINGERPRINT" "$_enable_fingerprint_default")" &&\
    atfile.say.debug "Setting ${_envvar_prefix}_ENABLE_FINGERPRINT to $_include_fingerprint_depr\n↳ ${_envvar_prefix}_INCLUDE_FINGERPRINT (deprecated) set to 1" &&\
    _enable_fingerprint=$_include_fingerprint_depr

### Validation

[[ $_output_json == 1 ]] && [[ $_max_list == $_max_list_default ]] &&\
    atfile.say.debug "Setting ${_envvar_prefix}_MAX_LIST to $_max_list_fallback\n↳ ${_envvar_prefix}_OUTPUT_JSON set to 1" &&\
    _max_list=$_max_list_fallback
[[ $(( $_max_list > $_max_list_fallback )) == 1 ]] &&\
    atfile.say.debug "Setting ${_envvar_prefix}_MAX_LIST to $_max_list_fallback\n↳ Maximum is $_max_list_fallback" &&\
    _max_list=$_max_list_fallback

## Git detection

if [ -x "$(command -v git)" ] && [[ -d "$_prog_dir/.git" ]] && [[ "$(atfile.util.get_realpath "$(pwd)")" == "$_prog_dir" ]]; then
    _is_git=1
fi

## OS detection

atfile.say.debug "Checking OS ($_os) is supported..."
is_os_supported=0

if [[ $_os != "unknown-"* ]] &&\
   [[ $_os == "bsd-"* ]] ||\
   [[ $_os == "haiku" ]] ||\
   [[ $_os == "linux" ]] ||\
   [[ $_os == "linux-mingw" ]] ||\
   [[ $_os == "linux-termux" ]] ||\
   [[ $_os == "macos" ]] ; then
    is_os_supported=1
fi

if [[ $is_os_supported == 0 ]]; then
    if [[ $_skip_unsupported_os_warn == 0 ]]; then
        atfile.die "Unsupported OS ($(echo $_os | sed s/unknown-//g))\n↳ Set ${_envvar_prefix}_SKIP_UNSUPPORTED_OS_WARN=1 to ignore"
    else
        atfile.say.debug "Skipping unsupported OS warning\n↳ ${_envvar_prefix}_SKIP_UNSUPPORTED_OS_WARN is set ($_skip_unsupported_os_warn)"
    fi
fi

## Directory creation

atfile.say.debug "Creating necessary directories..."
atfile.util.create_dir "$_path_cache"
atfile.util.create_dir "$_path_blobs_tmp"

## Program detection

_prog_hint_jq="https://jqlang.github.io/jq"

if [[ "$_os" == "haiku" ]]; then
    _prog_hint_jq="pkgman install jq"
fi

atfile.say.debug "Checking required programs..."
atfile.util.check_prog "curl" "https://curl.se"
[[ $os != "haiku" && $os != "solaris" ]] && atfile.util.check_prog "file" "https://www.darwinsys.com/file"
atfile.util.check_prog "jq" "$_prog_hint_jq"
[[ $_skip_ni_md5sum == 0 ]] && atfile.util.check_prog "md5sum" "" "${_envvar_prefix}_SKIP_NI_MD5SUM"

## Lifecycle commands

if [[ $_is_sourced == 0 ]] && [[ $_command == "" || $_command == "help" || $_command == "h" || $_command == "--help" || $_command == "-h" ]]; then
    atfile.help
    atfile.util.print_seconds_since_start_debug
    exit 0
fi

if [[ $_command == "update" ]]; then
    atfile.invoke.update
    atfile.util.print_seconds_since_start_debug
    exit 0
fi

if [[ $_command == "version" || $_command == "--version" ]]; then
    echo -e "$_version"
    atfile.util.print_seconds_since_start_debug
    exit 0
fi

## Command aliases

if [[ $_is_sourced == 0 ]]; then
    case "$_command" in
        "open"|"print"|"c") _command="cat" ;;
        "rm") _command="delete" ;;
        "download"|"f"|"d") _command="fetch" ;;
        "download-crypt"|"fc"|"dc") _command="fetch-crypt" ;;
        "fp") _command="fyi" ;;
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

## Authentication

if [[ $_is_sourced == 0 ]]; then
    [[ -z "$_username" || "$_username" == "<your-username>" ]] && atfile.die "\$${_envvar_prefix}_USERNAME not set"
    [[ -z "$_password" || "$_password" == "<your-password>" ]] && atfile.die "\$${_envvar_prefix}_PASSWORD not set"
fi

atfile.auth

## Protocol handling

if [[ "$_command" == "atfile:"* || "$_command" == "at:"* || "$_command" == "https:"* ]]; then
    set -- "handle" "$_command"
    _command="handle"
fi

## Commands

if [[ $_is_sourced == 0 ]] && [[ $ATFILE_DEVEL_NO_INVOKE != 1 ]]; then
    atfile.say.debug "Running '$_command_full'...\n↳ Command: $_command\n↳ Arguments: ${@:2}"

    case "$_command" in
        "blob")
            case "$2" in
                "list"|"ls"|"l") atfile.invoke.blob_list "$3" ;;
                "upload"|"u") atfile.invoke.blob_upload "$3" ;;
                *) atfile.die.unknown_command "$(echo "$_command $2" | xargs)" ;;
            esac  
            ;;
        "bsky"|"fyi")
            if [[ -z "$2" ]]; then
                atfile.util.override_actor "$_username"
                atfile.util.print_override_actor_debug
                atfile.profile "$_command" "$_username"
            else
                atfile.profile "$_command" "$2"
            fi
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
        "now")
            atfile.invoke.now "$2"
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
            if [[ $ATFILE_DEVEL == 1 ]]; then
                atfile.release
            else
                atfile.die "Not running from Devel environment"
            fi
            ;;
        "resolve")
            atfile.resolve "$2"
            ;;
        "something-broke")
            atfile.something_broke
            ;;
        "stream")
            atfile.invoke.stream "$2"
            ;;
        "token")
            atfile.invoke.token
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

atfile.util.print_seconds_since_start_debug
