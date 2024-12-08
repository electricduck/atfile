#!/usr/bin/env bash

function atfile.release() {
    #[[ $_version == *"+"* ]] && atfile.die "Not a stable version ($_version)"

    atfile.util.check_prog "git"
    atfile.util.check_prog "md5sum"

    id="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)"
    commit_author="$(git config user.name) <$(git config user.email)>"
    commit_hash="$(git rev-parse HEAD)"
    commit_date="$(git show --no-patch --format=%ci $commit_hash)"
    dist_file="$(echo "$_prog" | cut -d "." -f 1)-${_version}.sh"
    dist_dir="$_prog_dir/bin"
    dist_path="$dist_dir/$dist_file"
    parsed_version="$(atfile.util.parse_version "$_version")"
    version_record_id="atfile-$parsed_version"

    atfile.say "Building ATFile $_version ($id)..."

    mkdir -p "$dist_dir"

    echo "↳ Creating '$dist_file' (at '$(dirname "$dist_path")')..."
    echo "#!/usr/bin/env bash" > "$dist_path"

    echo -e "\n# ATFile <https://github.com/ziodotsh/atfile>
# ---
# Version: $_version
# Commit:  $commit_hash
# Author:  $commit_author
# Build:   $id ($(hostname) [$(atfile.util.get_os)])     
# ---
# Psst! You can 'source ./atfile.sh' in your own Bash scripts!
" >> $dist_path

    for s in "${ATFILE_DEVEL_SOURCES[@]}"
    do
        if [[ "$s" != "commands/release" ]]; then
            path="$(atfile.devel.get_source_path "$s")"

            if [[ -f "$path" ]]; then
                echo "↳ Compiling: $s"
                #cat "$path" | tail -n +3 >> "$dist_path"

                while IFS="" read -r line
                do
                    if [[ $line != "#"* ]] &&\
                       [[ $line != *"    #"* ]] &&\
                       [[ $line != "" ]]; then
                        echo "$line" >> "$dist_path"
                    fi
                done < "$path"
            fi
        else
            echo "↳ Skipping: $s"
        fi
    done
    
    echo -e "\n# \"Four million lines of BASIC\"\n#  - Kif Kroker (3003)" >> "$dist_path"

    chmod +x "$dist_path"

    if [[ $_devel_publish == 1 ]]; then
        checksum="$(atfile.util.get_md5 "$dist_path")"

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
