#!/usr/bin/env bash

function atfile.something_broke() {
    prog_not_installed_placeholder="(Not Installed)"

    function atfile.something_broke.print_envvar() {
        variable_name="${_envvar_prefix}_$1"
        variable_default="$2"
        
        unset output
        
        output="$variable_name: $(atfile.util.get_envvar "$variable_name" "$variable_default")"
        [[ -n "$variable_default" ]] && output+=" [$variable_default]"
        
        echo -e "↳ $output"
    }

    function atfile.something_broke.print_prog_version() {
        prog="$1"
        version_arg="$2"

        [[ -z "$version_arg" ]] && version_arg="--version"

        if [ -x "$(command -v $prog)" ]; then
            eval "$prog $version_arg 2>&1"
        else
            echo "$prog_not_installed_placeholder"
        fi
    }

    if [[ $_output_json == 1 ]]; then
        atfile.die "Command not available as JSON"
    fi
    
    unset md5sum_version
    finger_record="$(atfile.util.get_finger_record 1)"
    mediainfo_version="$(atfile.something_broke.print_prog_version "mediainfo")"

    if [[ $_os == "linux-musl" ]]; then
        md5sum_version="$(atfile.something_broke.print_prog_version "md5sum" "--help")"
    else
        md5sum_version="$(atfile.something_broke.print_prog_version "md5sum")"
    fi
    
    if [[ "$md5sum_version" != "$prog_not_installed_placeholder" ]]; then
        md5sum_version="$(echo "$md5sum_version" | head -n 1)"
        if [[ "$md5sum_version" == *GNU* ]]; then
            md5sum_version="$(echo "$md5sum_version" | cut -d " " -f 4) (GNU)"
        elif [[ "$md5sum_version" == *BusyBox* ]]; then
            md5sum_version="$(echo "$md5sum_version" | cut -d " " -f 2 | cut -d "v" -f 2) (BusyBox)"
        else
            md5sum_version="(?)"
        fi
    fi
    
    if [[ "$mediainfo_version" != "$prog_not_installed_placeholder" ]]; then
        mediainfo_version="$(echo "$mediainfo_version" | grep "MediaInfoLib" | cut -d "v" -f 2)"
    fi
    
    debug_output="ATFile
↳ Version: $_version
↳ UAS: $(atfile.util.get_uas)
↳ Path: $_prog_path
Variables
$(atfile.something_broke.print_envvar "DEBUG" $_debug_default)
$(atfile.something_broke.print_envvar "DEVEL")
$(atfile.something_broke.print_envvar "DEVEL_DIR")
$(atfile.something_broke.print_envvar "DEVEL_ENTRY")
$(atfile.something_broke.print_envvar "DEVEL_PUBLISH" $_devel_publish_default)
↳ ${_envvar_prefix}_DEVEL_SOURCES:
$(for s in "${ATFILE_DEVEL_SOURCES[@]}"; do echo " ↳ $s"; done)
$(atfile.something_broke.print_envvar "DISABLE_UPDATER" $_disable_updater_default)
↳ ${_envvar_prefix}_DIST_PASSWORD: $([[ -n $(atfile.util.get_envvar "${_envvar_prefix}_DIST_PASSWORD") ]] && echo "(Set)")
$(atfile.something_broke.print_envvar "DIST_USERNAME" $_dist_username_default)
$(atfile.something_broke.print_envvar "ENABLE_FINGERPRINT" $_enable_fingerprint_default)
$(atfile.something_broke.print_envvar "ENABLE_UPDATE_GIT_CLOBBER" $_enable_update_git_clobber)
$(atfile.something_broke.print_envvar "ENDPOINT_APPVIEW_BSKY" $_endpoint_appview_bsky_default)
$(atfile.something_broke.print_envvar "ENDPOINT_JETSTREAM" $_endpoint_jetstream_default)
$(atfile.something_broke.print_envvar "ENDPOINT_PDS")
$(atfile.something_broke.print_envvar "ENDPOINT_PLC_DIRECTORY" $_endpoint_plc_directory_default)
$(atfile.something_broke.print_envvar "ENDPOINT_RESOLVE_HANDLE" $_endpoint_resolve_handle_default)
$(atfile.something_broke.print_envvar "FMT_BLOB_URL" "$_fmt_blob_url_default")
$(atfile.something_broke.print_envvar "FMT_OUT_FILE" "$_fmt_out_file_default")
$(atfile.something_broke.print_envvar "FORCE_META_AUTHOR")
$(atfile.something_broke.print_envvar "FORCE_META_DID")
$(atfile.something_broke.print_envvar "FORCE_META_REPO")
$(atfile.something_broke.print_envvar "FORCE_META_YEAR")
$(atfile.something_broke.print_envvar "FORCE_NOW")
$(atfile.something_broke.print_envvar "FORCE_OS")
$(atfile.something_broke.print_envvar "FORCE_VERSION")
$(atfile.something_broke.print_envvar "INCLUDE_FINGERPRINT" $_enable_fingerprint_default)
$(atfile.something_broke.print_envvar "MAX_LIST" $_max_list_default)
$(atfile.something_broke.print_envvar "OUTPUT_JSON" $_output_json_default)
$(atfile.something_broke.print_envvar "PATH_CONF" "$_path_envvar")
$(atfile.something_broke.print_envvar "SKIP_AUTH_CHECK" $_skip_auth_check_default)
$(atfile.something_broke.print_envvar "SKIP_COPYRIGHT_WARN" $_skip_copyright_warn_default)
$(atfile.something_broke.print_envvar "SKIP_NI_EXIFTOOL" $_skip_ni_exiftool_default)
$(atfile.something_broke.print_envvar "SKIP_NI_MD5SUM" $_skip_ni_md5sum_default)
$(atfile.something_broke.print_envvar "SKIP_NI_MEDIAINFO" $_skip_ni_mediainfo_default)
$(atfile.something_broke.print_envvar "SKIP_UNSUPPORTED_OS_WARN" $_skip_unsupported_os_warn)
↳ ${_envvar_prefix}_PASSWORD: $([[ -n $(atfile.util.get_envvar "${_envvar_prefix}_PASSWORD") ]] && echo "(Set)")
$(atfile.something_broke.print_envvar "USERNAME")
Paths
↳ Blobs: $_path_blobs_tmp
↳ Cache: $_path_cache
↳ Config: $_path_envvar
Environment
↳ OS: $_os ($(echo "$finger_record" | jq -r ".os"))
↳ Shell: $SHELL
↳ Path: $PATH
Deps
↳ Bash: $BASH_VERSION
↳ curl: $(atfile.something_broke.print_prog_version "curl" "--version" | head -n 1 | cut -d " " -f 2)
↳ ExifTool: $(atfile.something_broke.print_prog_version "exiftool" "-ver")
↳ jq: $(atfile.something_broke.print_prog_version "jq" | sed -e "s|jq-||g")
↳ md5sum: $md5sum_version
↳ MediaInfo: $mediainfo_version
Misc.
↳ Checksum: $([[ "$md5sum_version" != "$prog_not_installed_placeholder" ]] && md5sum "$_prog_path" || echo "(?)")
↳ Dimensions: $(atfile.util.get_term_cols) Cols / $(atfile.util.get_term_rows) Rows
↳ Now: $_now
↳ Sudo: $SUDO_USER"
    
    atfile.say "$debug_output"
}
