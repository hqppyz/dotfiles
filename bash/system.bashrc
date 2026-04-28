shopt -s autocd # Use folders name as implicit cd

alias sudo="sudo "
alias update-dotfolder="bash $DOTFOLDER/update.sh"

alias nano="nano --rcfile $DOTFOLDER/nanorc"
alias newsboat="newsboat -C $DOTFOLDER/newsboat/config -u $DOTFOLDER/newsboat/urls"

# Exclude root
if [[ -n "$EUID" && "$EUID" -ne 0 ]]; then
  source "$DOTFOLDER/bash/user.bashrc"
fi
