#!/usr/bin/env bash

function atfile.bsky_video() {
    file_or_job_id="$1"

    function atfile.bsky_video.get_job_status() {
        app.bsky.video.getJobStatus "$1"
    }

    uploaded_video="$(app.bsky.video.uploadVideo "$1")"

    while true; do
        status="$(app.bsky.video.getJobStatus "$(echo "$uploaded_video" | jq -r ".jobId")")"

        percentage=$(echo "$status" | jq -r ".jobStatus.progress")
        state=$(echo "$status" | jq -r ".jobStatus.state")

        [[ $(atfile.util.is_null_or_empty "$percentage") == 1 ]] && percentage=0

        echo "$state ($percentage%)"

        if [[ $state == "JOB_STATE_COMPLETED" ]]; then
            break
        fi
    done
}
