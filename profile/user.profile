# export XDG_CONFIG_DIRS="$XDG_CONFIG_DIRS:$DOTFOLDER/user"

# Anti $HOME pollution
export LESSHISTFILE=-
export WGETRC="$DOTFOLDER/system/wget/wgetrc"
export WINEPREFIX="$XDG_DATA_HOME"/wine
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java -Dorg.bytedeco.javacpp.cachedir=$XDG_CACHE_HOME/javacpp"
export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle
export GOPATH="$XDG_DATA_HOME"/go
export CARGO_HOME="$XDG_DATA_HOME"/cargo
export PATH="$PATH:$CARGO_HOME/bin"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME"/npm
export ICEAUTHORITY="$XDG_CACHE_HOME"/ICEauthority
