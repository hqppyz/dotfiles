#!/usr/bin/env bash

DRY_RUN=false
if [[ "$1" == "--dry" ]]; then
  DRY_RUN=true
  echo "Attempting dry run"
fi

echo "Sourcing dependencies..."
WORKDOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKDOTDIR/scripts/require-dotfolder"
source require-colors

# Runs as the DOTFOLDER owner, only the /etc edits go through sudo
source require-owner "$DOTFOLDER"

echo "${C_BLUE}Giving everybody partial rights to $DOTFOLDER${C_RESET}"
"$DRY_RUN" || {
  # Only touch what lacks the bits, since even a no-op chmod bumps ctime
  # and Claude reloads the mods when it sees their files change
  find "$DOTFOLDER" ! -perm -a=r -exec chmod a+r {} +
  find "$DOTFOLDER/scripts" \( -type d -o -perm /111 \) ! -perm -a=x -exec chmod a+x {} +
}

# Runs the command as is when the owner can write $1 and its directory,
# else through sudo, which asks for the password on first use only
priv() {
  local target="$1"
  shift
  if [[ -w "$target" && -w "$(dirname "$target")" ]]; then "$@"; else sudo "$@"; fi
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

# Drops every dotfiles include: a marker line plus the include under it,
# or an older include with the marker trailing on the same line
remove_dotfile_includes() {
  priv "$1" sed -E -i \
    -e '/^# (Ap|Pre)pended by dotfiles \[.*\]$/{N;d}' \
    -e '/# (Ap|Pre)pended by dotfiles \[.*\]$/d' \
    "$1"
}

# True when $1 already has a $2 marker (Ap or Pre) of any commit directly
# above the include line $3, so a new commit alone does not rewrite the file
dotfile_include_current() {
  grep -A1 -E "^# ${2}pended by dotfiles \[.*\]$" "$1" | sed -n 2p | grep -Fxq -- "$3"
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

  local src="$1"; [[ "$src" == /* ]] || src="$DOTFOLDER/$1"
  local fmt="$2"
  local marker="# Prepended by dotfiles [$DOTFILES_VER]"
  local include="${fmt//%s/"$src"}"

  dotfile_include_current "$target" Pre "$include" && return 0

  echo "${C_BLUE}Prepending $src to $target${C_RESET}"
  "$DRY_RUN" || {
    remove_dotfile_includes "$target"
    # sed has no line 1 to insert before in an empty file
    if [[ -s "$target" ]]; then
      priv "$target" sed -i "1i\\
$marker\\
$include" "$target"
    else
      printf '%s\n%s\n' "$marker" "$include" | priv "$target" tee "$target" > /dev/null
    fi
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

  local src="$1"; [[ "$src" == /* ]] || src="$DOTFOLDER/$1"
  local fmt="$2"
  local marker="# Appended by dotfiles [$DOTFILES_VER]"
  local include="${fmt//%s/"$src"}"

  dotfile_include_current "$target" Ap "$include" && return 0

  echo "${C_BLUE}Appending $src to $target${C_RESET}"
  "$DRY_RUN" || {
    local replaced=false
    grep -Eq "# (Ap|Pre)pended by dotfiles \[.*\]$" "$target" && replaced=true
    remove_dotfile_includes "$target"
    [ -n "$(tail -c 1 "$target")" ] && echo | priv "$target" tee -a "$target" > /dev/null
    "$replaced" || echo | priv "$target" tee -a "$target" > /dev/null
    printf '%s\n%s\n' "$marker" "$include" | priv "$target" tee -a "$target" > /dev/null
  }

  return 0
}

# Merges the JSON file $2 (relative to DOTFOLDER) into the JSON file $1 and
# records what it did under a "_dotfiles" key of $1:
#   commit       DOTFILES_VER of the last merge
#   original     dotted key path -> value before the merge (null: key was absent)
#   replacement  dotted key path -> value the merge wrote
# Objects merge leaf by leaf, arrays are leaves too but merge as a union.
# Rerunning drops the keys that left $2 (restoring their original), keeps the
# saved originals and applies $2 again. @DOTFOLDER@ in $2 becomes DOTFOLDER, @HOME@ becomes HOME.
# Limit: dotted key paths cannot tell apart object keys that contain a dot.
merge_dotfile_json() {
  local target="$1"
  local src="$DOTFOLDER/$2"
  local merged

  if [[ ! -f "$src" ]]; then
    echo "${C_RED}ERROR: $src does not exist${C_RESET}" >&2
    return 1
  fi

  "$DRY_RUN" && { echo "${C_BLUE}Merging $src into $target${C_RESET}"; return 0; }

  mkdir -p "$(dirname "$target")"
  [[ -f "$target" ]] || echo '{}' > "$target"

  merged="$(jq --arg commit "$DOTFILES_VER" \
    --argjson src "$(sed "s|@DOTFOLDER@|$DOTFOLDER|g; s|@HOME@|$HOME|g" "$src")" '
    def leaves($p):
      if type == "object" then to_entries[] | . as $e | $e.value | leaves($p + [$e.key])
      else {key: ($p | join(".")), value: .} end;
    def drop($p):
      delpaths([$p]) | reduce range(($p | length) - 1; 0; -1) as $n (.;
        if getpath($p[0:$n]) == {} then delpaths([$p[0:$n]]) else . end);
    def restore($k; $o; $r):
      ($k | split(".")) as $p | getpath($p) as $cur
      | if ($r[$k] | type) == "array" then
          (($cur // []) - ($r[$k] - ($o[$k] // []))) as $a
          | if $a == [] and $o[$k] == null then drop($p) else setpath($p; $a) end
        elif $o[$k] == null then drop($p)
        else setpath($p; $o[$k]) end;

    (._dotfiles // {}) as $b
    | ($b.original // {}) as $o0
    | ($b.replacement // {}) as $r0
    | ([$src | leaves([])] | from_entries) as $new
    | reduce ($r0 | keys[]) as $k (.; if $new | has($k) then . else restore($k; $o0; $r0) end)
    | {d: ., o: ($o0 | with_entries(. as $e | select($new | has($e.key))))}
    | reduce ($new | keys[]) as $k (.;
        ($k | split(".")) as $p
        | (.d | getpath($p)) as $cur
        | .o[$k] = (if .o | has($k) then .o[$k] else $cur end)
        | .d |= setpath($p;
            if ($new[$k] | type) == "array" then ($cur // []) + ($new[$k] - ($cur // []))
            else $new[$k] end))
    | .d + {_dotfiles: {commit: $commit, original: .o, replacement: $new}}
  ' "$target")" || {
    echo "${C_RED}ERROR: Could not merge $src into $target${C_RESET}" >&2
    return 1
  }

  # The commit alone changes on every release, which Claude reports as a settings change
  if [[ "$(jq -S 'del(._dotfiles.commit)' <<< "$merged")" == "$(jq -S 'del(._dotfiles.commit)' "$target")" ]]; then
    return 0
  fi

  echo "${C_BLUE}Merging $src into $target${C_RESET}"
  printf '%s\n' "$merged" > "$target.tmp" && mv "$target.tmp" "$target"
}

# Claude Code only reads its user scope, so the dotfiles go in there
# instead of /etc/claude-code, which every claude process would inherit
CLAUDE_HOME="$HOME/.claude"
merge_dotfile_json "$CLAUDE_HOME/settings.json" "claude/settings.json"
"$DRY_RUN" || { mkdir -p "$CLAUDE_HOME" && { [[ -e "$CLAUDE_HOME/CLAUDE.md" ]] || touch "$CLAUDE_HOME/CLAUDE.md"; }; }
append_dotfile "$CLAUDE_HOME/CLAUDE.md" -- "claude/CLAUDE.md" '@%s'

# Agent prompts, roles and the aigents mod live in their own repo
AIGENTS="$HOME/.local/src/aigents"
[[ -d "$AIGENTS" ]] || echo "${C_RED}Missing $AIGENTS, agent setup skipped${C_RESET}" >&2

# Codex does not expand @ includes, so explicitly tell it to read the source.
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
[[ -d "$AIGENTS" ]] && { "$DRY_RUN" || { mkdir -p "$CODEX_DIR" && { [[ -e "$CODEX_DIR/AGENTS.md" ]] || touch "$CODEX_DIR/AGENTS.md"; }; }; }
[[ -d "$AIGENTS" ]] && append_dotfile "$CODEX_DIR/AGENTS.md" -- "$AIGENTS/codex/AGENTS.md" 'Read and follow `%s` explicitly at the start of each session.'

BASH_INCLUDE='[ -r "%s" ] && . "%s"'
prepend_dotfile "/etc/profile" -- "profile/system.profile" "$BASH_INCLUDE"
prepend_dotfile "/etc/bash/bashrc" "/etc/bash.bashrc" "/etc/bashrc" -- "bash/system.bashrc" "$BASH_INCLUDE"

INPUTRC_INCLUDE='$include %s'
append_dotfile "/etc/inputrc" -- "inputrc" "$INPUTRC_INCLUDE"

# kitty reads only the first config dir holding a kitty.conf, so the user one
# includes the dotfiles first and its own settings override them
KITTY_DIR="${KITTY_CONFIG_DIRECTORY:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
"$DRY_RUN" || { mkdir -p "$KITTY_DIR" && { [[ -e "$KITTY_DIR/kitty.conf" ]] || touch "$KITTY_DIR/kitty.conf"; }; }
prepend_dotfile "$KITTY_DIR/kitty.conf" -- "kitty/kitty.conf" 'include %s'

# mpv reads /etc/mpv first and ~/.config/mpv after it, so user files override
for f in mpv.conf input.conf; do
  [[ "$(readlink "/etc/mpv/$f")" == "$DOTFOLDER/system/mpv/$f" ]] && continue
  echo "${C_BLUE}Linking $DOTFOLDER/system/mpv/$f into /etc/mpv${C_RESET}"
  "$DRY_RUN" || {
    sudo mkdir -p /etc/mpv
    sudo ln -sf "$DOTFOLDER/system/mpv/$f" "/etc/mpv/$f"
  }
done

echo "${C_GREEN}Installation successful!${C_RESET}"
