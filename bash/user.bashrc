# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Exclude root
if [[ -z "$EUID" || "$EUID" -eq 0 ]]; then
  return 0
fi

source require-colors

PROMPT_COMMAND='build_prompt'
build_prompt() {
  local exit_code=$?
  local exit_color="${C_CYAN}"
  if [ "$exit_code" -ne 0 ]; then
    exit_color="${C_RED}"
  fi

  # local background_color="${C_RED_BG}"
  # if [ "$EUID" -eq 0 ]; then
  #   printf '\x1b]21;background=red\x1b\\' # Root indicator
  # fi

  local repository=""
  local changes_star=""
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local repository_branch=$(basename $(git rev-parse --show-toplevel))
    local repository_name=$(git rev-parse --abbrev-ref HEAD)
    repository="${C_GREEN}[$repository_branch@$repository_name] "

    if git ls-files --others --exclude-standard --directory | grep -q .; then
      # Untracked files
      changes_star="${C_RED}*"
    elif ! git diff --quiet || ! git diff --cached --quiet; then
      # Uncommitted changes
      changes_star="${C_GREEN}*"
    fi
  fi

  PS1="$repository${C_PURPLE}\W$changes_star $exit_color> ${C_WHITE}"
  #local left_prompt="${C_PURPLE}\W$changes_star $exit_color> ${C_WHITE}"
  #local right_prompt="$repository"
  #PS1=$(printf "%*s\r%s\n" "$(($(tput cols) + 10))" "$right_prompt" "$left_prompt")
}

#PS1="\[\e[31m\]\w \$(if [ \$? == 0 ]; then echo \[\e[92m\]; fi)> \[\e[97m\]"
PS2="${C_CYAN}> ${C_WHITE}"
