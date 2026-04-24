#!/usr/bin/env bash

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

echo "${C_BLUE}Giving everybody reading partial rights to $DOTFOLDER${C_RESET}"
"$DRY_RUN" || chmod -R a+r "$DOTFOLDER" && chmod -R a+X "$DOTFOLDER"

prepend_dotfile() {
  local target="$1"
  local src="$DOTFOLDER/$2"

  echo "${C_BLUE}Prepending $src to $target${C_RESET}"
  "$DRY_RUN" || sed -i "1i [ -r \"$src\" ] && . \"$src\" # Prepended by dotfiles" "$target"
}

append_dotfile() {
  local target="$1"
  local src="$DOTFOLDER/$2"

  echo "${C_BLUE}Appending $src to $target${C_RESET}"
  "$DRY_RUN" || printf '\n[ -r "%s" ] && . "%s" # Appended by dotfiles\n' "$src" "$src" >> "$target"
}

append_dotfile "/etc/profile" "profile.sh"
prepend_dotfile "/etc/bash/bashrc" "bash/system.bashrc"
prepend_dotfile "/etc/bash/bashrc" "bash/user.bashrc"
#prepend_dotfile "/etc/bash/bashrc" "profile.sh"

unset -f prepend_dotfile
unset -f append_dotfile

echo "${C_GREEN}Success!${C_RESET}"
