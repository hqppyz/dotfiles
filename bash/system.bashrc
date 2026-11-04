if [ -z "$DOTFILES_LOADED" ]; then
  DOTFILES_LOADED=1
  . /opt/dotfiles/profile/system.profile
fi

#shopt -s autocd # Use folders name as implicit cd

alias sudo="sudo "
alias update-dotfolder="bash $DOTFOLDER/update.sh"

alias nano="nano --rcfile $DOTFOLDER/nano/rc"
alias newsboat="newsboat -C $DOTFOLDER/newsboat/config -u $DOTFOLDER/newsboat/urls"
command -v codium >/dev/null && alias code="codium"

alias ls="ls --color=auto"
alias la="ls -a"
alias grep="grep --color=auto"
alias less="less -R"
alias bat="bat --paging=never"

if command -v kitten >/dev/null; then
  cat() {
    if [[ -t 1 && -f "$1" && $(file --mime-type -b "$1") =~ ^image/ ]]; then
      kitten icat "$@"
    else
      command cat "$@"
    fi
  }
fi

# Exclude root
if [[ -n "$EUID" && "$EUID" -ne 0 ]]; then
  source "$DOTFOLDER/bash/user.bashrc"
fi
