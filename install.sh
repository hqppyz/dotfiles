# Requirements:
# git
# zsh
# Nightly NeoVim (opt)
# ripgrep (opt)
# fd-find (opt)

# Configurations
mkdir -p ~/.local/src/mdotfiles
git clone --depth 1 git@github.com:happyzleaf/mdotfiles.git ~/.local/src/mdotfiles

# ZSH
chsh -s $(which zsh)
echo "source ~/.local/src/mdotfiles/startup.sh" >> ~/.zshrc

