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
    "commands/old_cmds"
    "commands/release"
    "commands/something_broke"
    # Entry
    "entry"
)
