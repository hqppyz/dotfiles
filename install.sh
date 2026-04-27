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

resolve_dotfile_target() {
  local candidates=()
  local candidate
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    candidates+=("$1")
    shift
  done

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "${C_RED}ERROR: None of these files exist: ${candidates[*]}${C_RESET}" >&2
  return 1
}

prepend_dotfile() {
  local target="$(resolve_dotfile_target "$@")"
  [[ -z "$target" ]] && return 1

  while [[ $# -gt 0 && "$1" != "--" ]]; do
    shift
  done
  if [[ "$1" != "--" ]]; then
    echo "${C_RED}ERROR: Missing -- argument divider${C_RESET}" >&2
    return 1
  fi
  shift

  local src="$DOTFOLDER/$1"
  local fmt="$2"
  local marker="# Prepended by dotfiles [$DOTFILES_VER]"
  local marker_pattern="# Prepended by dotfiles \\[.*\\]$"
  local line="$(printf "$fmt" "$src" "$src") $marker"

  grep -Fq "$marker" "$target" && return 0

  echo "${C_BLUE}Prepending $DOTFOLDER/$1 to $target${C_RESET}"
  "$DRY_RUN" || {
    sed -i \
      -e "\|$marker_pattern|d" \
      "$target"
    sed -i "1i\\
$line" "$target"
  }

  return 0
}

append_dotfile() {
  local target="$(resolve_dotfile_target "$@")"
  [[ -z "$target" ]] && return 1

  while [[ $# -gt 0 && "$1" != "--" ]]; do
    shift
  done
  if [[ "$1" != "--" ]]; then
    echo "${C_RED}ERROR: Missing -- argument divider${C_RESET}" >&2
    return 1
  fi
  shift

  local src="$DOTFOLDER/$1"
  local fmt="$2"
  local marker="# Appended by dotfiles [$DOTFILES_VER]"
  local marker_pattern="# Appended by dotfiles \\[.*\\]$"
  local line="$(printf "$fmt" "$src" "$src") $marker"

  grep -Fq "$marker" "$target" && return 0

  echo "${C_BLUE}Appending $DOTFOLDER/$1 to $target${C_RESET}"
  "$DRY_RUN" || {
    local replaced=false
    grep -q "$marker_pattern" "$target" && replaced=true
    sed -i \
      -e "\|$marker_pattern|d" \
      "$target"
    "$replaced" && printf '%s' "$line" >> "$target" || printf '\n%s' "$line" >> "$target"
  }

  return 0
}

BASH_INCLUDE='[ -r "%s" ] && . "%s"'
prepend_dotfile "/etc/profile" -- "profile/system.profile" "$BASH_INCLUDE"
prepend_dotfile "/etc/bash/bashrc" "/etc/bash.bashrc" "/etc/bashrc" -- "bash/system.bashrc" "$BASH_INCLUDE"

INPUTRC_INCLUDE='$include %s'
append_dotfile "/etc/inputrc" -- "inputrc" "$INPUTRC_INCLUDE"

echo "${C_GREEN}Success!${C_RESET}"
