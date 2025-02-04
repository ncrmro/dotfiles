#!/bin/sh

set -eux

if [ ! -d $HOME/dotfiles ]; then
  mv /workspaces/.codespaces/.persistedshare/dotfiles $HOME/dotfiles
fi

cd $HOME/dotfiles

# Make passwordless sudo work
export SUDO_ASKPASS=/bin/true

# Change shell to zsh
sudo chsh "$(id -un)" --shell "/usr/bin/zsh"

stow nvim ruby zsh git

# Setup Neovim
# Install lazyvim plugins
$HOME/bin/nvim --headless -c 'luafile install-lazynvim.lua' -c 'qall'
