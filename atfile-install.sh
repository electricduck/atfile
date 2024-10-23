#!/usr/bin/env bash

function die() {
    echo -e "\033[1;31mError: $1\033[0m"
    exit 255
}

uid="$(id -u)"
tag="v/0.x/0.4.2"
url="https://raw.githubusercontent.com/electricduck/atfile/refs/tags/$tag/atfile.sh"

install_file="atfile"
conf_file="atfile.env"
unset install_dir
unset conf_dir

if [[ $uid == 0 ]]; then
    install_dir="/usr/local/bin"
    conf_dir="/root/.config"
else
    install_dir="$(eval echo ~$USER)/.local/bin"
    conf_dir="$(eval echo ~$USER)/.config"
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

echo -e "😎 Installed ATFile $(echo $tag | cut -d "/" -f 3)"
echo -e "   ↳ Path:   $install_dir/$install_file"
echo -e "   ↳ Config: $conf_dir/$conf_file"
echo -e "   ---"
echo -e "   Before running, set your credentials in the config file!"
echo -e "   Run '$install_file help' to get started"
#           ------------------------------------------------------------------------------
