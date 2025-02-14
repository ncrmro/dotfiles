# dotfiles

Largely inspired by Paul's [dotfiles](https://github.com/paul/dotfiles).

This repository contains configuration files (dotfiles) for various tools and applications. By using [GNU Stow](https://www.gnu.org/software/stow/), these configurations can easily be managed and deployed across different systems.

# Stow

GNU Stow is a symlink manager that simplifies the management of dotfiles by creating symbolic links from a central directory (this repository) to their target locations in your home directory. This keeps your configurations organized and portable.

For example, if you "stow" the nvim directory, Stow will link its contents into your home directory (e.g., ~/.config/nvim).

# Initial Setup

Install [brew](https://brew.sh/) for both linux or mac.

Ensure you have GNU Stow installed on your system. Ripgrep and Lazygit are needed later.

```shell
brew install stow ripgrep jesseduffield/lazygit/lazygit
```

Then clone this repo somewhere. Then unstow a configuration. (Not it will error if any files would be overwritten)

For instance running 

```shell
stow nvim
```

Will create the following symslink

```
./dotfiles/nvim/.config/nvim -> ~/.config/nvim
```

# Moving new configs 

Create a new directory in the dotfile repo and commit, then running stow will symlink them back into the correct dir!.


# NVIM

Unstowing nvim will install [lazyvim](https://www.lazyvim.org/)

Make sure to install latest neovim `brew install neovim` and a font `brew install --cast font-jetbrains-mono-nerd-font`

Installing the `zsh.` will also add a nice theme and some plugins.

When running nvim in a code dir. 

The leader key `space` will bring up a menu with short cuts. For instance 

- `space` then `f` (file) then
  - side file explorer `e`
  - fuzzy file search `f` 
  - terminal `t`
- short cut for git commands `:` then `G`
  -  `G commit -m "fea: foobar"`
- fold code under the cursor `z` then `c`
- vertical windows split `w` then `v`
- cut/copy/delete `v` to start "visual mode" (select text with arrow keys) then
  - `y` to "yank" copy
  - `p` to paste
  - `d` to delete
- When you have multiple files open they are called "buffers" (tabs are diffrent)
  -  `space` then `,` will bring up a fuzzy search of your buffers
  - `space` then `b` will allow you to open/close switch buffers.
- To comment code out press `v` and select lines.
  - then `gc`  
