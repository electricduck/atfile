#!/usr/bin/env bash

declare -a ATFILE_DEVEL_SOURCES=(
    # Shared
    "shared/die" 
    "shared/say"
    "shared/util"
    "shared/http"
    "shared/xrpc"
    "shared/lexi"
    # Commands
    "commands/ai"
    "commands/auth"
    "commands/help"
    "commands/profile"
    "commands/release"
    "commands/resolve"
    "commands/stream"
    "commands/sl"
    "commands/something_broke"
    "commands/update"
    # Commands (Legacy)
    "commands/old_cmds"
    # Entry
    "entry"
)
