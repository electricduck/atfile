#!/usr/bin/env bash

function atfile.help() {
    if [[ $_output_json == 1 ]]; then
        atfile.die "Command not available as JSON"
    fi

    unset error
    unset handle

    resolved_did="$(atfile.util.resolve_identity "$_meta_did")"
    error="$(atfile.util.get_xrpc_error $? "$resolved_did")"
    
    if [[ -n "$error" ]]; then
        handle="invalid.handle"
    else
        handle="$(echo "$resolved_did" | cut -d "|" -f 3 | sed -s 's/at:\/\///g')"
    fi

# ------------------------------------------------------------------------------
    usage_commands="Commands
    upload <file> [<key>]
        Upload new file to the PDS
        ⚠️  ATProto records are public: do not upload sensitive files\n        
    list [<cursor>] [<actor>]
    list <actor> [<cursor>]
        List all uploaded files. Only $_max_list items can be displayed; to
        paginate, use the last Key for <cursor>\n
    fetch <key> [<actor>]
        Download an uploaded file\n
    cat <key> [<actor>]
        Print (don't download) an uploaded file to the shell\n
    url <key> [<actor>]
        Get blob URL for an uploaded file\n
    info <key> [<actor>]
        Get full details for an uploaded file\n
    delete <key>
        Delete an uploaded file
        ⚠️  No confirmation is asked before deletion\n
    lock <key>
    unlock <key>
        Lock (or unlock) an uploaded file to prevent it from unintended
        deletions
        ⚠️  Other clients may be able to delete the file. This is intended as
           a safety-net to avoid inadvertently deleting the wrong file\n
    upload-crypt <file> <recipient> [<key>]
        Encrypt file (with GPG) for <recipient> and upload to the PDS
        ℹ️  Make sure the necessary GPG key has been imported first\n
    fetch-crypt <file> [<actor>]
        Download an uploaded encrypted file and attempt to decrypt it (with
        GPG)
        ℹ️  Make sure the necessary GPG key has been imported first"

    usage_commands_devel="Commands (Devel)
    release
        Build (and release) as one file (to ./bin)
        ℹ️  Set ${_envvar_prefix}_DEVEL_PUBLISH=1 to upload release"

    usage_commands_lifecycle="Commands (Lifecycle)
    update
        Check for updates and update if outdated
        ⚠️  If installed from your system's package manager, self-updating is
           not possible\n
    toggle-mime
        Install/uninstall desktop file to handle atfile:/at: protocol"

    usage_commands_profiles="Commands (AppViews)
    bsky [<actor>]
        Get Bluesky profile for <actor>\n
    bsky-video [<file>]
    bsky-video [<job-id>]
        ...
    fyi [actor]
        Get Frontpage profile for <actor>"

    usage_commands_tools="Commands (Tools)
    blob list
        List blobs on authenticated repository\n
    blob upload <path>
        Upload blobs to authenticated repository
        ℹ️  Unless referenced by a record shortly after uploading, blob will be
           garbage collected by the PDS\n
    handle <at-uri>
        Open at:// URI with relevant App\n
    handle <atfile-uri> [<handler>]
        Open atfile:// URI with relevant App
        ℹ️  Set <handler> to a .desktop entry (with '.desktop') to force the
           application <atfile-uri> opens with\n
    now
        Get date in ISO-8601 format\n
    record add <record-json> [<collection>]
    record get <key> [<collection>] [<actor>]
    record get <at-uri>
    record put <key> <record-json> [<collection>]
    record put <at-uri> <record-json>
    record rm <key> [<collection>]
    record rm <at-uri>
        Manage records on a repository
        ⚠️  No validation is performed. Here be dragons!
        ℹ️  <collection> defaults to '$_nsid_upload'\n
    resolve <actor>
        Get details for <actor>\n
    stream [<collection(s)>] [<did(s)>] [<cursor>] [<compress>]
        Stream records from Jetstream
        ℹ️  For multiple values (where appropriate) separate with ';'\n
    token
        Get JWT for authenticated account"

    usage_envvars="Environment Variables
    ${_envvar_prefix}_USERNAME <string> (required)
        Username of the PDS user (handle or DID)
    ${_envvar_prefix}_PASSWORD <string> (required)
        Password of the PDS user
        ℹ️  An App Password is recommended
           (https://bsky.app/settings/app-passwords)\n
    ${_envvar_prefix}_ENABLE_FINGERPRINT <bool¹> (default: $_enable_fingerprint_default)
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
        If you're confident your credentials are correct, and
        \$${_envvar_prefix}_USERNAME is a DID (*not* a handle), this will
        drastically improve performance!
    ${_envvar_prefix}_SKIP_COPYRIGHT_WARN <bool¹> (default: $_skip_copyright_warn_default)
        Do not print copyright warning when uploading files to
        https://bsky.social
    ${_envvar_prefix}_SKIP_NI_EXIFTOOL <bool¹> (default: $_skip_ni_exiftool_default)
        Do not check if ExifTool is installed
        ⚠️  If Exiftool is not installed, the relevant metadata records will
           not be created:
           * image/*: $_nsid_meta#photo
    ${_envvar_prefix}_SKIP_NI_MD5SUM <bool¹> (default: $_skip_ni_md5sum_default)
        Do not check if MD5Sum is installed
    ${_envvar_prefix}_SKIP_NI_MEDIAINFO <bool¹> (default: $_skip_ni_mediainfo_default)
        Do not check if MediaInfo is installed
        ⚠️  If MediaInfo is not installed, the relevant metadata records will
           not be created:
           * audio/*: $_nsid_meta#audio
           * video/*: $_nsid_meta#video
    ${_envvar_prefix}_SKIP_UNSUPPORTED_OS_WARN <bool¹> (default: $_skip_unsupported_os_warn)
        Do not error when running on an unsupported OS\n
    ${_envvar_prefix}_ENDPOINT_JETSTREAM <url> (default: $_endpoint_jetstream_default)
        Endpoint of the Jetstream relay
    ${_envvar_prefix}_ENDPOINT_PDS <url>
        Endpoint of the PDS
        ℹ️  Your PDS is resolved from your username. Set to override it (or if
           resolving fails)
    ${_envvar_prefix}_ENDPOINT_PLC_DIRECTORY <url> (default: ${_endpoint_plc_directory_default}$([[ $_endpoint_plc_directory_default == *"zio.blue" ]] && echo "²"))
        Endpoint of the PLC directory
    ${_envvar_prefix}_ENDPOINT_RESOLVE_HANDLE <url> (default: ${_endpoint_resolve_handle_default}$([[ $_endpoint_plc_directory_default == *"zio.blue" ]] && echo "²"))
        Endpoint of the PDS/AppView used for handle resolving\n
    ${_envvar_prefix}_DEBUG <bool¹> (default: $_debug_default)
        Print debug outputs
        ⚠️  When output is JSON (${_envvar_prefix}_OUTPUT_JSON=1), sets to 0
    ${_envvar_prefix}_DISABLE_UPDATE_CHECKING <bool¹> (default: $_disable_update_checking_default)
        Disable periodic update checking when command finishes
    ${_envvar_prefix}_DISABLE_UPDATER <bool¹> (default: $_disable_updater_default)
        Disable \`update\` command\n
    ¹ A bool in Bash is 1 (true) or 0 (false)
    ² These servers are ran by @$handle. You can trust us!"

    usage_paths="Paths
    $_path_envvar
        List of key/values of the above environment variables. Exporting these
        on the shell (with \`export \$ATFILE_VARIABLE\`) overrides these values
        ℹ️  Set ${_envvar_prefix}_PATH_CONF to override\n
    $_path_cache/
    $_path_blobs_tmp/
        Cache and temporary storage"

    usage="ATFile"
    [[ $_os != "haiku" ]] && usage+=" | 📦 ➔ 🦋"

    usage+="\n    Store and retrieve files on the ATmosphere\n
    Version $_version
    (c) $_meta_year $_meta_author <$_meta_repo>
    Licensed as MIT License ✨\n
    😎 Stay updated with \`$_prog update\`
    🦋 Follow @$handle on Bluesky
       ↳ https://bsky.app/profile/$handle\n
Usage
    $_prog <command> [<arguments>]
    $_prog at://<actor>[/<collection>/<rkey>]
    $_prog atfile://<actor>/<key>\n\n"

    [[ $ATFILE_DEVEL == 1 ]] && usage+="$usage_commands_devel\n\n"
    usage+="$usage_commands\n\n"
    usage+="$usage_commands_lifecycle\n\n"
    usage+="$usage_commands_tools\n\n"
    usage+="$usage_commands_profiles\n\n"
    usage+="$usage_envvars\n\n"
    usage+="$usage_paths\n"

    if [[ $_debug == 1 ]]; then
        atfile.say.debug "Printing help..."
        echo -e "$usage"
    else
        echo -e "$usage" | less
    fi

    [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$_meta_did'" "$error"

# ------------------------------------------------------------------------------
}
