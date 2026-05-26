#!/usr/bin/env bash

echo "Sourcing dependencies..."
WORKDOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKDOTDIR/scripts/require-dotfolder"
source require-colors

# Changing the directory to DOTFOLDER
cd "$DOTFOLDER"

# Check if the update is being run by the owner of the DOTFOLDER
source require-owner .

# Check if there are mods in the folder
if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
  echo "${C_RED}ERROR: Refusing to update because $DOTFOLDER has local changes.${C_RESET}" >&2
  echo "${C_RED}Commit, stash, or discard them before running this script.${C_RESET}" >&2
  git status --short >&2
  exit 1
fi

# Pull origin master
echo "${C_BLUE}Updating $DOTFOLDER from origin/master...${C_RESET}"
git pull --ff-only origin master

# Run install.sh
echo "${C_BLUE}Running installer...${C_RESET}"
sudo bash install.sh

echo "${C_GREEN}Update successful!${C_RESET}"
