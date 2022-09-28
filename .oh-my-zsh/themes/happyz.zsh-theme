PROMPT='%{$fg_bold[yellow]%}%c$(git_dirty)%{$fg_bold[yellow]%}>%{$reset_color%} '
RPROMPT='$(git_branch)%{$fg_bold[green]%}%~%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[blue]%}://"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# Based on: https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/git.zsh
function git_check() {
  # If we are on a folder not tracked by git, get out.
  # Otherwise, check for hide-info at global and local repository level
  if ! __git_prompt_git rev-parse --git-dir &> /dev/null \
     || [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
    return 0
  fi
  
  return 1
}

function git_dirty() {
  if git_check; then
    return 0;
  fi

  echo "%{$reset_color%}$(parse_git_dirty)%{$reset_color%}"
}

function git_branch() {
  if git_check; then
    return 0;
  fi

  local ref
  ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null) \
  || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) \
  || return 0

  echo "%{$reset_color%}${ZSH_THEME_GIT_PROMPT_PREFIX}${ref:gs/%/%%}${upstream:gs/%/%%}${ZSH_THEME_GIT_PROMPT_SUFFIX}%{$reset_color%}"
}
