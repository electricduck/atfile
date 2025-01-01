#!/usr/bin/env bash

#       _  _____ _____ _ _
#      / \|_   _|  ___(_| | ___
#     / _ \ | | | |_  | | |/ _ \
#    / ___ \| | |  _| | | |  __/
#   /_/   \_|_| |_|   |_|_|\___|
#
#  -------------------------------------------------------------------------------
#
#   Welcome to ATFile's crazy Bash codebase!
#
#   Unless you're wanting to tinker, its recommended you install a stable version
#    of ATFile: see README for more. Using a development version against your
#    ATProto account could potentially inadvertently damage records.
#
#   Just as a published build, ATFile can be used entirely via this file. The
#    below code automatically sources everything for you, and your config (if
#    it exists) is utilized as normal. Try running `./atfile.sh help`. To turn
#    debug messages off, set ATFILE_DEBUG to '0'.
#
#   To produce a single-file build of ATFile, run `./atfile.sh release`: the
#    resulting file will be created at './bin/atfile-$version.sh'. Set variables
#    below (under '# Meta') to adjust various properties: these will be adjusted
#    during build automatically.
#
#   Published releases are also done from here. This is done with:
#    * Setting ATFILE_DEVEL_PUBLISH to '1'
#    * Setting ATFILE_DIST_USERNAME to 'did:web:zio.sh' (default)
#    * Setting ATFILE_DIST_PASSWORD to the above account's password
#    * Running `./atfile.sh release`. After build, the resulting file is uploaded
#
#   Being a fairly atypical codebase, please don't hesitate to get in touch if
#    you're wanting to contribute but bewildered by this hot mess. Message
#    either @zio.sh or @ducky.ws on Bluesky for help.
#
#   Here be dragons.
#
#  -------------------------------------------------------------------------------

# Meta

author="zio"
did="did:web:zio.sh"
repo="https://github.com/ziodotsh/atfile"
version="0.10.8"
year="$(date +%Y)"

# Entry

function atfile.devel.die() {
    echo -e "\033[1;31mError: $1\033[0m" >&2
    exit 255
}

if [[ "$0" != "$BASH_SOURCE" ]]; then
    atfile.devel.die "Unable to source"
fi

ATFILE_DEVEL=1
ATFILE_DEVEL_DIR="$(dirname "$(realpath "$0")")"
ATFILE_DEVEL_ENTRY="$(realpath "$0")"

if [ ! -x "$(command -v git)" ]; then
    atfile.devel.die "'git' not installed (download: https://git-scm.com/downloads/linux)"
fi

git describe --exact-match --tags > /dev/null 2>&1
[[ $? != 0 ]] && version+="+git.$(git rev-parse --short HEAD)"

# BUG: Clobbers variables from config file
[[ -z $ATFILE_FORCE_META_AUTHOR ]] && ATFILE_FORCE_META_AUTHOR="$author"
[[ -z $ATFILE_FORCE_META_DID ]] && ATFILE_FORCE_META_DID="$did"
[[ -z $ATFILE_FORCE_META_REPO ]] && ATFILE_FORCE_META_REPO="$repo"
[[ -z $ATFILE_FORCE_META_YEAR ]] && ATFILE_FORCE_META_YEAR="$year"
[[ -z $ATFILE_FORCE_VERSION ]] && ATFILE_FORCE_VERSION="$version"

declare -a ATFILE_DEVEL_SOURCES

for f in "$ATFILE_DEVEL_DIR/src/commands/"*; do ATFILE_DEVEL_SOURCES+=("$f"); done
for f in "$ATFILE_DEVEL_DIR/src/lexi/"*; do ATFILE_DEVEL_SOURCES+=("$f"); done
for f in "$ATFILE_DEVEL_DIR/src/shared/"*; do ATFILE_DEVEL_SOURCES+=("$f"); done
ATFILE_DEVEL_SOURCES+=("$ATFILE_DEVEL_DIR/src/entry.sh")

for path in "${ATFILE_DEVEL_SOURCES[@]}"
do
    if [[ ! -f "$path" ]]; then
        atfile.devel.die "Unable to find source for '$path'"
    fi

    source "$path"
done
