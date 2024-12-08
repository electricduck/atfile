#!/usr/bin/env bash

function atfile.say() {
    message="$1"
    prefix="$2"
    color_prefix="$3"
    color_message="$4"
    color_prefix_message="$5"
    suffix="$6"
    
    prefix_length=0

    if [[ $_os == "haiku" ]]; then
        message="$(echo "$message" | sed 's/↳/>/g')"
    fi
    
    [[ -z $color_prefix_message ]] && color_prefix_message=0
    [[ -z $suffix ]] && suffix="\n"
    [[ $suffix == "\\" ]] && suffix=""
    
    if [[ -z $color_message ]]; then
        color_message="\033[0m"
    else
        color_message="\033[${color_prefix_message};${color_message}m"
    fi
    
    if [[ -z $color_prefix ]]; then
        color_prefix="\033[0m"
    else
        color_prefix="\033[1;${color_prefix}m"
    fi
    
    if [[ -n $prefix ]]; then
        prefix_length=$(( ${#prefix} + 2 ))
        prefix="${color_prefix}${prefix}: \033[0m"
    fi
    
    message="$(echo "$message" | sed -e "s|\\\n|\\\n$(atfile.util.repeat_char " " $prefix_length)|g")"
    
    echo -n -e "${prefix}${color_message}$message\033[0m${suffix}"
}

function atfile.say.debug() {
    message="$1"

    if [[ $_debug == 1 ]]; then
        atfile.say "$message" "Debug" 35
    fi
}

function atfile.say.die() {
    message="$1"
    atfile.say "$message" "Error" 31 31 1
}

function atfile.say.inline() {
    message="$1"
    color="$2"
    atfile.say "$message" "" "" $color "" "\\"
}
