#!/usr/bin/env bash

DRY_RUN=false
if [[ "$1" == "--dry" ]]; then
  DRY_RUN=true
  echo "${C_MAGENTA}Attempting dry run${C_RESET}"
fi

echo "Sourcing dependencies..."
"$DRY_RUN" || unset DOTFOLDER
source profile/system.profile
source require-sudo
source require-colors

if [[ -z "$DOTFOLDER" ]]; then
   echo "${C_RED}ERROR: Could not find DOTFOLDER${C_RESET}"
   exit 1
fi

echo "${C_BLUE}Giving everybody reading partial rights to $DOTFOLDER${C_RESET}"
"$DRY_RUN" || chmod -R a+r "$DOTFOLDER" && chmod -R a+X "$DOTFOLDER/scripts"

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
  "$DRY_RUN" || printf '\n[ -r "%s" ] && . "%s" # Appended by dotfiles' "$src" "$src" >> "$target"
}

append_dotfile "/etc/profile" "profile/system.profile"
append_dotfile "/etc/profile" "profile/user.profile"
prepend_dotfile "/etc/bash/bashrc" "bash/system.bashrc"
prepend_dotfile "/etc/bash/bashrc" "bash/user.bashrc"

unset -f prepend_dotfile
unset -f append_dotfile

echo "${C_GREEN}Success!${C_RESET}"
