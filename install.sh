#!/usr/bin/env bash

DRY_RUN=false
if [[ "$1" == "--dry" ]]; then
  DRY_RUN=true
  echo "Attempting dry run"
fi

echo "Sourcing dependencies..."
unset DOTFOLDER
source profile/system.profile
source require-sudo
source require-colors

if [[ -z "$DOTFOLDER" ]]; then
   echo "${C_RED}ERROR: Could not find DOTFOLDER${C_RESET}"
   exit 1
fi

echo "${C_BLUE}Giving everybody partial rights to $DOTFOLDER${C_RESET}"
"$DRY_RUN" || {
  chmod -R a+r "$DOTFOLDER"
  chmod -R a+X "$DOTFOLDER/scripts"
}

prepend_dotfile() {
  local target="$1"
  local src="$DOTFOLDER/$2"
  local fmt="$3"
  local line="$(printf "$fmt" "$src" "$src") # Prepended by dotfiles"

  echo "${C_BLUE}Prepending $src to $target${C_RESET}"
  "$DRY_RUN" || sed -i "1i\\
$line" "$target"
}

append_dotfile() {
  local target="$1"
  local src="$DOTFOLDER/$2"
  local fmt="$3"
  local line="$(printf "$fmt" "$src" "$src") # Appended by dotfiles"

  echo "${C_BLUE}Appending $src to $target${C_RESET}"
  "$DRY_RUN" || printf '\n%s' "$line" >> "$target"
}

BASH_INCLUDE='[ -r "%s" ] && . "%s"'
append_dotfile "/etc/profile" "profile/system.profile" "$BASH_INCLUDE"
append_dotfile "/etc/profile" "profile/user.profile" "$BASH_INCLUDE"
prepend_dotfile "/etc/bash/bashrc" "bash/system.bashrc" "$BASH_INCLUDE"
prepend_dotfile "/etc/bash/bashrc" "bash/user.bashrc" "$BASH_INCLUDE"

INPUTRC_INCLUDE='$include %s'
append_dotfile "/etc/inputrc" "inputrc" "$INPUTRC_INCLUDE"

echo "${C_GREEN}Success!${C_RESET}"
