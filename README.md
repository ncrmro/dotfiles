# dotfiles

Largely inspired by Paul's [dotfiles](https://github.com/paul/dotfiles).

This repository contains configuration files (dotfiles) for various tools and applications. By using [GNU Stow](https://www.gnu.org/software/stow/), these configurations can easily be managed and deployed across different systems.

Keystone separates runtime provisioning from editable defaults. The
`ks.systems/terminal` product provisions terminal tools and generated runtime
wiring. The `ks.systems/desktop` product extends it with graphical tools.
`ncrmro/ks-config` selects those products for each host. This repository owns
the editable configuration for both products.

The layout lives under `packages/`, with one Stow package per tool:

```text
packages/
  bin/              .local/bin/
  git/              .config/git/config
  ssh/              .ssh/config
  hyprland-common/  .config/hypr/hyprland.lua
                    .config/uwsm/env-hyprland
  themes/           .config/keystone/theme-catalogs/user/
```

Keystone Terminal owns the shared `ks-stow-dotfiles` command and Home Manager
integration. This repository's `install.sh` only delegates to that command,
using this checkout and `$HOME`; without package arguments it selects `git ssh
zsh`. Enable Keystone Terminal or install its shared dotfiles tool first.

```shell
./install.sh
./install.sh git ssh
./install.sh --check themes
```

`--check` runs the same shared validation and Stow simulation as deployment.
The shared installer checks selected package files and their exact destination
paths. It does not search the home directory for stale links. Existing user
files remain conflicts to resolve explicitly; installation does not adopt or
overwrite them. Deleted or renamed files require an exact-path migration; see
[MIGRATIONS.md](MIGRATIONS.md).

Run the small wrapper tests with `./tests/install-wrapper.sh`. The shared
installer's behavior tests live in `ks.systems/terminal`. Run this repository's
package-content and fleet-composition suite with `./tests/run.sh`; it requires
`ks-stow-dotfiles` on PATH, GNU coreutils, Zsh, and `ssh-agent`. The Hyprland
composition test also builds pinned Hyprland and Lua 5.4 using Nix. Set both
`HYPRLAND_BIN` and `LUA_BIN` to compatible local executables to avoid those
builds. Tests use disposable homes and package copies.

Configuration in `packages/` should refer to dependencies by executable name,
not by `/nix/store` path, so Nix can continue to own dependency provisioning.
The `themes` package is the sparse, highest-precedence user catalog. It owns
only intentional overrides and complete user-only themes. Omarchy,
`ks.systems/terminal`, and `ks.systems/desktop` provide the lower layers.
Keystone MAY compose those layers, switch the active theme, and reload
applications. Keystone MUST NOT generate or replace these editable files.

`ks.systems/terminal` ships the same terminal files as starter templates. Its
seed command copies missing defaults into a new user's dotfiles tree. The seed
command MUST NOT overwrite an existing file unless the user passes `--force`.
After seeding, this repository is the source of truth for local edits.

The complete user-only `royal-green` theme provides `zellij.kdl` and defines
its palette as `current`. Shared palettes live in `ks.systems/terminal`.

## Hyprland and UWSM

Hyprland 0.56 loads `~/.config/hypr/hyprland.lua`. The common package owns the
base settings, typed dispatchers, binds, and rules. It loads these optional
customizations in this order:

1. `~/.config/themes/current/hyprland.lua`
2. `~/.config/hypr/user.lua`
3. `~/.config/hypr/host.lua`

The theme uses `loadfile` and `pcall`. A theme error is isolated and the base
configuration remains valid. The user and host modules use protected `require`
calls. Hyprland 0.56 diagnoses a missing module. It also records a module parse
or runtime error as a configuration error, even when `pcall` catches it. The
base policy loads before these modules. Keystone's startup lock gates the
remaining graphical services.

Each graphical host adds one host package:

- `hyprland-workstation` provides the workstation monitor and defaults.
- `hyprland-laptop` provides the laptop panel.
- `hyprland-delltop` provides the test-laptop monitor fallback.

Theme directories that customize Hyprland provide `hyprland.lua`. The active
theme selector points `~/.config/themes/current` at one theme directory. Old `hyprland.conf`, `ncrmro.conf`, and `host.conf` links require the exact-path
cleanup described in [MIGRATIONS.md](MIGRATIONS.md).

`ks.systems/desktop` generates `.config/uwsm/env` because the generic session
environment is runtime wiring. This repository retains
`.config/uwsm/env-hyprland` for editable Hyprland-specific cursor preferences.
Do not reconstruct profile paths or add manual systemd or D-Bus environment
imports here. Graphical launch binds use `uwsm app --`. Keystone's systemd user
units own persistent background processes.

Hyprland ecosystem tools keep their own Hyprlang files. These files are
`hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`, `hyprsunset.conf`, and
`xdph.conf`.

## packages/bin — small shell scripts

Scripts that need nothing but a shell and coreutils live in
`packages/bin/.local/bin/` and stow onto `$HOME/.local/bin`, which is already on
PATH. Prefer this to a Nix wrapper or a Home Manager activation block when a
script has no dependencies to provision: it stays plain text, editable in place,
and testable by running it.

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`, and commit the file
  executable (`chmod +x`).
- Call tools by bare name, never by `/nix/store` path — Nix owns provisioning.
- Keep the script idempotent. It may run on every invocation.
- If a script grows a real dependency, add it to the `bin` entry in the
  `toolDeps` manifest in `ks-config` rather than hardcoding a path.

Because `install.sh` stows with `--no-folding`, `$HOME/.local/bin` stays a real
directory and only the individual scripts inside it become symlinks. Anything
else already installed there (for example a `claude` launcher) is left alone.

Current scripts:

- `claude-work` — runs Claude Code against the work account's config dir
  (`~/.claude-work`) so it keeps its own credentials, while linking the
  session-bearing paths in that dir to `~/.claude`. `--resume` and `--continue`
  then list the same sessions under both `claude` and `claude-work`.

## OBS desktop recording template

The `obs` package installs an editable 16:9 desktop recording layout and an
`obs-template` command. It generates native scene-collection/profile imports
for macOS or Linux, with a blurred circular webcam overlay, fit/fill desktop
views, a Desk Cam scene with the same circle overlay, and a fullscreen face-camera
intro scene.
See [the OBS setup guide](docs/obs.md) for installation, device selection and
saving later edits. OBS Studio and Python 3 must be provisioned on the host.

## Agent session palette spike

The `zellij` package includes an `agent-sessions` command for a low-fidelity
agent status palette. It stores short-lived JSON leases under
`$XDG_RUNTIME_DIR/agent-sessions/`. Run these commands inside two Zellij panes
to test the list and focus behavior:

```shell
agent-sessions set demo-one working --agent codex --step "test the palette"
agent-sessions set demo-two waiting --agent pi --tab another-tab --step "wait for input"
agent-sessions list
agent-sessions fzf
```

The command reads `ZELLIJ_SESSION_NAME` and `ZELLIJ_PANE_ID` when it writes a
lease. Press Enter in FZF to focus a selected pane in the current Zellij
session. Press Ctrl-R to reload the list. Cross-session desktop focus is not
part of this spike. A lease becomes `stale` after five minutes by default.
Set `AGENT_SESSIONS_STALE_AFTER` to change that interval. A later
`agent-sessions set demo-one idle` call preserves the existing metadata.

# Stow

GNU Stow is a symlink manager that simplifies the management of dotfiles by creating symbolic links from a central directory (this repository) to their target locations in your home directory. This keeps your configurations organized and portable.

For example, if you "stow" the nvim directory, Stow will link its contents into your home directory (e.g., ~/.config/nvim).

# Initial Setup

Install [brew](https://brew.sh/) for both linux or mac.

Ensure you have GNU Stow and GNU coreutils installed on your system. Ripgrep
and Lazygit are needed later.

```shell
brew install coreutils stow ripgrep jesseduffield/lazygit/lazygit
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
