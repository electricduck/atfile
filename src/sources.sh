#!/usr/bin/env bash

declare -a ATFILE_DEVEL_SOURCES=(
    # Shared
    "shared/die" 
    "shared/say"
    "shared/util"
    "shared/http"
    "shared/xrpc"
    "shared/js"
    "shared/lexi"
    # Commands
    "commands/auth"
    "commands/help"
    "commands/profile"
    "commands/release"
    "commands/resolve"
    "commands/something_broke"
    # Commands (Legacy)
    "commands/old_cmds"
    # Entry
    "entry"
)
