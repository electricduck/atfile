#!/usr/bin/env bash

function atfile.auth() {
    override_username="$1"
    override_password="$2"

    function atfile.auth.get_command_segment() {
        IFS=' ' read -r -a command_array <<< "$_command_full"
        index=$1
        #echo "$_command_full" | cut -d' ' -f$1
        echo "${command_array[index]}"
    }

    [[ -n "$override_password" ]] && _password="$override_password"
    [[ -n "$override_username" ]] && _username="$override_username"

    atfile.say.debug "Authenticating as '$_username'..."

    if [[ -z "$_server" ]]; then
        skip_resolving=0
        
        if [[ -z $override_username ]] && [[ $_is_sourced == 0 ]]; then
            # NOTE: Speeds things up a little if the user is overriding actor
            #       Keep this in-sync with the main command case below!
            if [[ $_command == "cat" && -n "$(atfile.auth.get_command_segment 2)" ]] ||\
               [[ $_command == "fetch" && -n "$(atfile.auth.get_command_segment 2)" ]] ||\
               [[ $_command == "fetch-crypt" && -n "$(atfile.auth.get_command_segment 2)" ]] ||\
               [[ $_command == "info" && -n "$(atfile.auth.get_command_segment 2)" ]] ||\
               [[ $_command == "list" && "$(atfile.auth.get_command_segment 1)" == *.* ]] ||\
               [[ $_command == "list" && "$(atfile.auth.get_command_segment 1)" == did:* ]] ||\
               [[ $_command == "list" && -n "$(atfile.auth.get_command_segment 2)" ]] ||\
               [[ $_command == "url" && -n "$(atfile.auth.get_command_segment 2)" ]]; then
                atfile.say.debug "Skipping identity resolving\n↳ Actor is overridden by command ('$_command_full')"
                skip_resolving=1 
            fi

            # NOTE: Speeds things up a little if the command doesn't need actor resolving
            if [[ $_command == "at:"* ]] ||\
            [[ $_command == "atfile:"* ]] ||\
            [[ $_command == "bsky" ]] ||\
            [[ $_command == "handle" ]] ||\
            [[ $_command == "now" ]] ||\
            [[ $_command == "release" ]] ||\
            [[ $_command == "resolve" ]] ||\
            [[ $_command == "something-broke" ]]; then
                atfile.say.debug "Skipping identity resolving\n↳ Not required for command '$_command'"
                skip_resolving=1
            fi
        fi
        
        if [[ $skip_resolving == 0 ]]; then
            atfile.say.debug "Resolving identity..."

            resolved_did="$(atfile.util.resolve_identity "$_username")"
            error="$(atfile.util.get_xrpc_error $? "$resolved_did")"
            [[ -n "$error" ]] && atfile.die.xrpc_error "Unable to resolve '$_username'" "$resolved_did"

            _username="$(echo $resolved_did | cut -d "|" -f 1)"
            _server="$(echo $resolved_did | cut -d "|" -f 2)"
            
            atfile.say.debug "Resolved identity\n↳ DID: $_username\n↳ PDS: $_server"
        fi
    else
        atfile.say.debug "Skipping identity resolving\n↳ ${_envvar_prefix}_ENDPOINT_PDS is set ($_server)"
        [[ $_server != "http://"* ]] && [[ $_server != "https://"* ]] && _server="https://$_server"
    fi

    if [[ -n $_server ]]; then
        if [[ $_skip_auth_check == 0 ]]; then
            atfile.say.debug "Checking authentication is valid..."
            
            session="$(com.atproto.server.getSession)"
            error="$(atfile.util.get_xrpc_error $? "$session")"

            if [[ -n "$error" ]]; then
                atfile.die.xrpc_error "Unable to authenticate" "$error"
            else
                _username="$(echo $session | jq -r ".did")"
            fi
        else
            atfile.say.debug "Skipping checking authentication validity\n↳ ${_envvar_prefix}_SKIP_AUTH_CHECK is set ($_skip_auth_check)"
            if [[ "$_username" != "did:"* ]]; then
                atfile.die "Cannot skip authentication validation without a DID\n↳ \$${_envvar_prefix}_USERNAME currently set to '$_username' (need \"did:<type>:<key>\")"
            fi
        fi
    fi
}
