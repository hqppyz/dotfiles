# Exclude root
if [[ -z "$EUID" || "$EUID" -eq 0 ]]; then
  return 0
fi

# export XDG_CONFIG_DIRS="$XDG_CONFIG_DIRS:$DOTFOLDER/user"
