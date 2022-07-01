SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Oh My ZSH
export ZSH="$SCRIPT_PATH/.oh-my-zsh"
ZSH_THEME="happyz"

# Config
export XDG_CONFIG_DIRS="$SCRIPT_PATH/.config:$XDG_CONFIG_DIRS"

