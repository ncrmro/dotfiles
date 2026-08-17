# Dotfiles editing contract

This repository owns user-editable configuration. GNU Stow MUST link these
files into the user's home directory. Nix MUST NOT own or generate an editable
file after initial seeding.

`ks.systems/terminal` MUST own terminal packages, services, credentials,
generated runtime fragments, the theme selector, and user-agnostic starter
templates. `ks.systems/desktop` MUST depend on `ks.systems/terminal`. It MAY
extend the theme contract with graphical adapters and reload hooks.

The starter terminal templates and the terminal files in `packages/` MUST stay
in sync. Changes SHOULD start here for rapid iteration. A change MUST also
update the starter template when it changes the default for a new user.

Every theme MUST provide these terminal adapters:

- `zellij.kdl`
- `helix.toml`
- `btop.theme`
- `lazygit.yml`

A headless host MUST support theme selection without the desktop product.
Desktop theme extensions MUST NOT replace the terminal selector or redeclare
`keystone.terminal.theme.name`.
