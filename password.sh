#!/usr/bin/env bash

# depends on tofi, ydotool, and pass     #TODO encode this into nix
shopt -s nullglob globstar

dmenu=tofi
xdotool="ydotool type --file -"

prefix=${PASSWORD_STORE_DIR-~/.password-store}
password_files=( "$prefix"/**/*.gpg )
password_files=( "${password_files[@]#"$prefix"/}" )
password_files=( "${password_files[@]%.gpg}" )

password=$(printf '%s\n' "${password_files[@]}" | tofi --prompt-text="site <username>: " "$@")

[[ -n $password ]] || exit

pass show "$password" | { IFS= read -r pass; printf %s "$pass"; } | $xdotool
