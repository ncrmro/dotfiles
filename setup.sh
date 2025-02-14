#!/bin/sh

set -eux

env | sort

if command -v brew &>/dev/null; then
    echo "Homebrew is already installed."
    brew --version
else
    echo "Homebrew is not installed, installing now..."
     NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install stow fzf nvim ripgrep jesseduffield/lazygit/lazygit rbenv vale pyenv

if [ -n "${CODESPACES-}" ]; then
  ./setup-codespaces.sh
fi
