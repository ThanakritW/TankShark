#!/bin/sh
printf '\033c\033]0;%s\a' TankShark
base_path="$(dirname "$(realpath "$0")")"
"$base_path/TankShark.x86_64" "$@"
