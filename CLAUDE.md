# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal dotfiles repository using GNU Stow for symlink-based configuration management. The repository contains shell configurations, Neovim setup with LazyVim, Git aliases, and Ruby version management.

## Setup Commands

### Initial Setup
```bash
# Install required tools
brew install stow ripgrep jesseduffield/lazygit/lazygit rbenv vale pyenv

# Run complete setup (installs Homebrew if needed)
./setup.sh

# For GitHub Codespaces
./setup-codespaces.sh
```

### Configuration Management
```bash
# Deploy specific configurations using stow
stow nvim      # Symlinks nvim config to ~/.config/nvim
stow zsh       # Symlinks zsh config to ~/.zshrc and oh-my-zsh
stow git       # Symlinks git config to ~/.gitconfig
stow ruby      # Symlinks .ruby-version

# Deploy all configs for codespaces
stow nvim ruby zsh git
```

## Architecture

### Directory Structure
- `nvim/` - Neovim configuration with LazyVim framework
- `zsh/` - Zsh shell configuration with oh-my-zsh and plugins
- `git/` - Git configuration with useful aliases
- `ruby/` - Ruby version specification (3.3.4)

### Key Configuration Files
- `nvim/.config/nvim/init.lua` - Neovim entry point that bootstraps LazyVim
- `zsh/.zshrc` - Zsh configuration with oh-my-zsh plugins and environment setup
- `git/.gitconfig` - Git configuration with aliases and core settings

### Environment Setup
- Uses Homebrew for package management (Linux and macOS)
- Rbenv for Ruby version management with auto-initialization
- Pyenv for Python version management
- Sources secrets from `~/.secrets.sh` if present
- Git configuration includes `~/.gitconfig.local` for user-specific settings

### Shell Plugins and Tools
The zsh configuration includes plugins for: gem, git, git-extras, github, kubectl, kubectx, nvm, rails, rake, rbenv, and ssh.

## Important Notes
- All configurations use symlinks via GNU Stow - never edit files in home directory directly
- Git configuration expects user-specific settings in `~/.gitconfig.local`
- Neovim uses LazyVim with custom plugins in `lua/plugins/`
- Setup scripts handle both regular systems and GitHub Codespaces environments