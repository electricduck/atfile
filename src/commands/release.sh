#!/usr/bin/env bash

function atfile.release() {
    [[ $_os != "linux" ]] && atfile.die "Only available on Linux (GNU)\n↳ Detected OS: $_os"

    function atfile.release.replace_template_var() {
        string="$1"
        key="$2"
        value="$3"

        echo "$(echo "$string" | sed -s "s|{:$key:}|$value|g")"
    }

    atfile.util.check_prog "git"
    atfile.util.check_prog "md5sum"

    id="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)"
    commit_author="$(git config user.name) <$(git config user.email)>"
    commit_hash="$(git rev-parse HEAD)"
    commit_date="$(git show --no-patch --format=%ci $commit_hash)"
    dist_file="$(echo "$_prog" | cut -d "." -f 1)-${_version}.sh"
    dist_dir="$_prog_dir/bin"
    dist_path="$dist_dir/$dist_file"
    dist_path_relative="$(realpath --relative-to="$(pwd)" "$dist_path")"
    parsed_version="$(atfile.util.parse_version "$_version")"
    version_record_id="atfile-$parsed_version"

    atfile.say "Building ATFile $_version ($id)..."

    mkdir -p "$dist_dir"

    echo "↳ Creating '$dist_file'..."
    echo "#!/usr/bin/env bash" > "$dist_path"

    echo -e "\n# ATFile <https://github.com/ziodotsh/atfile>
# ---
# Version: $_version
# Commit:  $commit_hash
# Author:  $commit_author
# Build:   $id ($(hostname):$(atfile.util.get_os))     
# ---
# Psst! You can \`source atfile\` in your own Bash scripts!
" >> $dist_path

    for s in "${ATFILE_DEVEL_SOURCES[@]}"
    do
        if [[ "$s" != "commands/release" ]]; then
            if [[ -f "$s" ]]; then
                echo "↳ Compiling: $s"

                while IFS="" read -r line
                do
                    if [[ $line != "#"* ]] &&\
                       [[ $line != *"    #"* ]] &&\
                       [[ $line != "    " ]] &&\
                       [[ $line != "" ]]; then
                        if [[ $line == *"{:"* && $line == *":}"* ]]; then
                            # NOTE: Not using atfile.util.get_envvar() here, as confusion can arise from config file
                            line="$(atfile.release.replace_template_var "$line" "meta_author" $ATFILE_FORCE_META_AUTHOR)"
                            line="$(atfile.release.replace_template_var "$line" "meta_did" $ATFILE_FORCE_META_DID)"
                            line="$(atfile.release.replace_template_var "$line" "meta_repo" $ATFILE_FORCE_META_REPO)"
                            line="$(atfile.release.replace_template_var "$line" "meta_year" $ATFILE_FORCE_META_YEAR)"
                            line="$(atfile.release.replace_template_var "$line" "version" $ATFILE_FORCE_VERSION)"
                        fi

                        echo "$line" >> "$dist_path"
                    fi
                done < "$s"
            fi
        else
            echo "↳ Skipping: $s"
        fi
    done
    
    echo -e "\n# \"Four million lines of BASIC\"\n#  - Kif Kroker (3003)" >> "$dist_path"

    checksum="$(atfile.util.get_md5 "$dist_path")"

    echo -e "Built: $_version
↳ Path: ./$dist_path_relative
 ↳ Check: $checksum
 ↳ Size: "$(atfile.util.get_file_size_pretty "$(stat -c %s "$dist_path")")"
 ↳ Lines: $(atfile.util.fmt_int "$(cat "$dist_path" | wc -l)")
↳ ID: $id"

    chmod +x "$dist_path"

    if [[ $_devel_publish == 1 ]]; then
        echo "---"
        atfile.auth "$_dist_username" "$_dist_password"
        [[ $_version == *"+"* ]] && atfile.die "Cannot publish a Git version ($_version)"

        atfile.say "Uploading '$dist_path'..."
        atfile.invoke.upload "$dist_path" "" "$version_record_id"
        [[ $? != 0 ]] && atfile.die "Unable to upload '$dist_path'"
        echo "---"

        latest_release_record="{
    \"version\": \"$_version\",
    \"releasedAt\": \"$(atfile.util.get_date "$_commit_date")\",
    \"commit\": \"$commit_hash\",
    \"id\": \"$id\",
    \"checksum\": \"$checksum\"
}"

        atfile.say "Updating latest record to $_version..."
        atfile.invoke.manage_record put "at://$_username/self.atfile.latest/self" "$latest_release_record" &> /dev/null
    fi
}
