#!/usr/bin/env bash

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

    [[ -z "$gui_error" ]] && gui_error="$cli_error"
 
    if [ -x "$(command -v zenity)" ] && [[ $_is_sourced == 0 ]]; then
        zenity --error --text "$gui_error"
    fi

    atfile.die "$cli_error"
}

function atfile.die.gui.xrpc_error() {
    message="$1"
    xrpc_error="$2"
    message_cli="$message"

    [[ "$xrpc_error" == "?" ]] && unset xrpc_error
    [[ -n "$xrpc_error" ]] && message_cli="$message\n↳ $xrpc_error"

    atfile.die.gui \
        "$message_cli" \
        "$message"
}

function atfile.die.xrpc_error() {
    message="$1"
    xrpc_error="$2"

    [[ "$xrpc_error" == "?" ]] && unset xrpc_error
    [[ -n "$xrpc_error" ]] && message="$message\n↳ $xrpc_error"

    atfile.die "$message"
}

function atfile.die.unknown_command() {
    command="$1"
    atfile.die "Unknown command '$1'"
}
