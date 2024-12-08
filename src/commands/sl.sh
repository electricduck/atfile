#!/usr/bin/env bash

function atfile.sl() {
    if [ -x "$(command -v sl)" ]; then
        sl
    else
        echo -e "\n  choo choo 🚂\n"
    fi
}
