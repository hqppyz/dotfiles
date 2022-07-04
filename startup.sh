SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Config
export XDG_CONFIG_DIRS="$SCRIPT_PATH/.config:$XDG_CONFIG_DIRS"

# Oh My ZSH
export ZSH="$SCRIPT_PATH/.oh-my-zsh"
ZSH_THEME="happyz"
plugins=(git)
source $ZSH/oh-my-zsh.sh

