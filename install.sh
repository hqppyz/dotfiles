#!/bin/bash

echo "Sourcing dependencies..."
source profile.sh
source require-sudo
source require-colors

if [[ -z "$DOTFOLDER" ]]; then
   echo "${C_RED}ERROR: Could not find DOTFOLDER${C_RESET}"
   exit 1
fi

DRY_RUN=false
if [[ "$1" == "--dry" ]]; then
  DRY_RUN=true
  echo "${C_MAGENTA}Attempting dry run${C_RESET}"
fi

append_file() {
  local target="$1"
  local src="$DOTFOLDER/$2"

  echo "${C_BLUE}Appending $src to $target${C_RESET}"
  "$DRY_RUN" || printf '\n[ -r "%s" ] && . "%s" # Appended by dotfiles\n' "$src" "$src" >> "$target"
}

append_file "/etc/profile" "profile.sh"

unset -f append_file

echo "${C_GREEN}Success!${C_RESET}"
