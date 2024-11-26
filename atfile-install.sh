#!/usr/bin/env bash

function die() {
    echo -e "\033[1;31mError: $1\033[0m"
    exit 255
}

function check_prog() {
    prog="$1"
    ! [ -x "$(command -v $prog)" ] && die "'$prog' not installed"
}

function get_os() {
    os="${OSTYPE,,}"

    case $os in
        # Linux
        "linux-gnu") echo "linux" ;;
        "cygwin") echo "linux-cygwin" ;;
        "linux-musl") echo "linux-musl" ;;
        "linux-android") echo "linux-termux" ;;
        # BSD
        "freebsd"*) echo "bsd-freebsd" ;;
        "netbsd"*) echo "bsd-netbsd" ;;
        "openbsd"*) echo "bsd-openbsd" ;;
        # Misc.
        "haiku") echo "haiku" ;;
        "darwin"*) echo "macos" ;;
        "solaris"*) echo "solaris" ;;
        # Unknown
        *) echo "unknown-$OSTYPE" ;;
    esac
}

function parse_version() {
    version="$1"
    version="$(echo $version | cut -d "+" -f 1)"
    v_major="$(printf "%04d\n" "$(echo $version | cut -d "." -f 1)")"
    v_minor="$(printf "%04d\n" "$(echo $version | cut -d "." -f 2)")"
    v_rev="$(printf "%04d\n" "$(echo $version | cut -d "." -f 3)")"
    echo "$(echo ${v_major}${v_minor}${v_rev} | sed 's/^0*//')"
}

function xrpc_get() {
    lexi="$1"
    collection="$2"
    key="$3"

    curl -s -L -X GET "$endpoint/$lexi?collection=$collection&repo=$did&rkey=$key"
}

check_prog "curl"
check_prog "jq"

uid="$(id -u)"
did="did:plc:wennm3p5pufuib7vo5ex4sqw"
endpoint="https://zio.blue/xrpc"
install_file="atfile"
conf_file="atfile.env"
unset install_dir
unset conf_dir

latest_version_record="$(xrpc_get "com.atproto.repo.getRecord" "self.atfile.latest" "self")"
[[ $? != 0 ]] && die "Unable to get latest version"

latest_version="$(echo "$latest_version_record" | jq -r '.value.version')"
parsed_latest_version="$(parse_version $latest_version)"
found_version_record="$(xrpc_get "com.atproto.repo.getRecord" "blue.zio.atfile.upload" "$parsed_latest_version")"
[[ $? != 0 ]] && die "Unable to fetch record for '$parsed_latest_version'"

found_version_blob="$(echo "$found_version_record" | jq -r ".value.blob.ref.\"\$link\"")"
url="https://zio.blue/blob/did:plc:wennm3p5pufuib7vo5ex4sqw/$found_version_blob"

if [[ $(get_os) == "haiku" ]]; then
    install_dir="/boot/system/non-packaged/bin"
    conf_dir="$HOME/config/settings"
else
    if [[ $uid == 0 ]]; then
        install_dir="/usr/local/bin"

        if [[ -z $SUDO_DIR ]]; then
            conf_dir="/root/.config"
        else
            conf_dir="$(eval echo ~$SUDO_USER)/.config"
        fi
    else
        install_dir="$(eval echo ~$USER)/.local/bin"
        conf_dir="$(eval echo ~$USER)/.config"
    fi
fi

mkdir -p "$install_dir"
[[ $? != 0 ]] && die "Unable to create install directory ($install_dir)"

curl -s -o "${install_dir}/$install_file" "$url"
[[ $? != 0 ]] && die "Unable to download"

chmod +x "${install_dir}/$install_file"
[[ $? != 0 ]] && die "Unable to set as executable"

mkdir -p "$conf_dir"
[[ $? != 0 ]] && die "Unable to create config directory ($conf_dir)"

if [[ ! -f "$conf_dir/$conf_file" ]]; then
    echo -e "ATFILE_USERNAME=<your-username>\nATFILE_PASSWORD=<your-password>" > "$conf_dir/$conf_file"
    [[ $? != 0 ]] && die "Unable to create config file ($conf_dir/$conf_file)"
fi

echo -e "😎 Installed ATFile"
echo -e "   ↳ Path:   $install_dir/$install_file"
echo -e "   ↳ Config: $conf_dir/$conf_file"
echo -e "   ---"
echo -e "   Before running, set your credentials in the config file!"
echo -e "   Run '$install_file help' to get started"
#           ------------------------------------------------------------------------------
