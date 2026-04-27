shopt -s autocd # Use folders name as implicit cd

alias sudo="sudo "
alias nano="nano --rcfile $DOTFOLDER/nanorc"

# Exclude root
if [[ -n "$EUID" && "$EUID" -ne 0 ]]; then
  source "$DOTFOLDER/bash/user.bashrc"
fi
