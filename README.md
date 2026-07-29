# dotfiles

Largely inspired by Paul's [dotfiles](https://github.com/paul/dotfiles).

This repository contains configuration files (dotfiles) for various tools and applications. By using [GNU Stow](https://www.gnu.org/software/stow/), these configurations can easily be managed and deployed across different systems.

On NixOS, `ncrmro/ks-config` provisions each tool and its dependencies while
this repository owns the editable configuration. The NixOS layout lives under
`packages/`, with one Stow package per tool:

```text
packages/
  git/              .config/git/config
  ssh/              .ssh/config
  hyprland-common/  .config/hypr/hyprland.conf
  themes/           .config/themes/
```

Home Manager restows the selected packages during activation. To do the same
manually:

```shell
./install.sh
./install.sh git ssh
./install.sh --check themes
```

Configuration in `packages/` should refer to dependencies by executable name,
not by `/nix/store` path, so Nix can continue to own dependency provisioning.
The `themes` package owns the editable desktop palettes and backgrounds.
Keystone may switch the active theme and reload applications, but it does not
generate or replace these files.

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

Create a new directory in the dotfile repo and commit, then running stow will symlink them back into the correct dir!


# NVIM

Unstowing nvim will install [lazyvim](https://www.lazyvim.org/)

Make sure to install latest neovim `brew install neovim` and a font `brew install --cast font-jetbrains-mono-nerd-font`

Installing the `zsh.` will also add a nice theme and some plugins.


## Keybindings

The leader key is `space`, which opens a menu with shortcuts:

- **File Operations:**
  - `space` + `f`:
    - `e`: Open side file explorer
    - `f`: Fuzzy file search
    - `t`: Open terminal
- **Git Commands:**
  - `:` + `G`: Open git command menu
    - Example: `G commit -m "fea: foobar"`
  - `space` + `g` + `g`: Open lazygit
- **Code Folding:**
  - `z` + `c`: Fold code under the cursor
- **Window Management:**
  - `w` + `v`: Vertical window split
- **Text Operations:**
  - `v`: Enter visual mode (use arrow keys to select text)
    - `y`: Yank (copy)
    - `p`: Paste
    - `d`: Delete
- **Buffer Management:**
  - `space` + `,`: Fuzzy search buffers
  - `space` + `b`: Open/close/switch buffers
- **Commenting Code:**
  - `v`: Select lines in visual mode
  - `gc`: Comment out selected lines
- **Indenting Multiple Lines:**
  - `v`: Select lines in visual mode
  - `shift` + `<` or `>` (left or right)
