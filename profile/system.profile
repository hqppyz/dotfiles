DOTFILES_LOADED=1
export DOTFOLDER="/opt/dotfiles"
export DOTFILES_VER="$(git -C "$DOTFOLDER" rev-parse --short HEAD 2>/dev/null || echo unknown)"
export PATH="$PATH:$DOTFOLDER/scripts"
if command -v codium >/dev/null; then
  export EDITOR="codium"
else
  export EDITOR="nano"
fi

# XDG spec defaults
export XDG_CONFIG_DIRS="$DOTFOLDER/system:${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export HISTCONTROL=ignoreboth:erasedups
export HISTFILE="$XDG_STATE_HOME"/bash/history

# Less colored display (for manpages) (from https://wiki.archlinux.org/index.php/Color_output_in_console#man)
export LESS_TERMCAP_mb=$'\e[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\e[1;33m'     # begin blink
export LESS_TERMCAP_so=$'\e[01;44;37m' # begin reverse video
export LESS_TERMCAP_us=$'\e[01;37m'    # begin underline
export LESS_TERMCAP_me=$'\e[0m'        # reset bold/blink
export LESS_TERMCAP_se=$'\e[0m'        # reset reverse video
export LESS_TERMCAP_ue=$'\e[0m'        # reset underline
export GROFF_NO_SGR=1                  # for konsole and gnome-terminal

# Exclude root
if [[ -n "$EUID" && "$EUID" -ne 0 ]]; then
  source "$DOTFOLDER/profile/user.profile"
fi
