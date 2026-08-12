#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
desktop=(
  bat btop clipse ghostty helix satty themes walker waybar wofi zellij
  hyprland-common
)

compositions=(
  # Mirrors dotfiles.packages per host in ks-config. Mercury is infrastructure,
  # not a development host, and keeps its own three-package list; maia does not
  # import the dotfiles module at all. Neither gets `bin`.
  "maia:git ssh zsh"
  "mercury:git ssh zsh"
  "ocean:bin git ssh zsh"
  "ncrmro-workstation:bin git ssh zsh ${desktop[*]} hyprland-workstation"
  "ncrmro-laptop:bin git ssh zsh ${desktop[*]} hyprland-laptop"
  "ks-test-delltop:bin git ssh zsh ${desktop[*]} hyprland-delltop"
)

for composition in "${compositions[@]}"; do
  host="${composition%%:*}"
  read -r -a packages <<<"${composition#*:}"
  test_home="$(mktemp -d)"
  trap 'rm -rf "${test_home}"' EXIT
  HOME="${test_home}" "${repo_dir}/install.sh" "${packages[@]}"
  HOME="${test_home}" "${repo_dir}/install.sh" --check "${packages[@]}"
  rm -rf "${test_home}"
  trap - EXIT
  printf 'ok: %s\n' "${host}"
done

hypridle_conf="${repo_dir}/packages/hyprland-common/.config/hypr/hypridle.conf"
hyprland_conf="${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.conf"

grep -Fxq '  before_sleep_cmd=keystone-lock --fail-closed' "${hypridle_conf}"
grep -Fxq '  inhibit_sleep=3' "${hypridle_conf}"
grep -Fxq '  lock_cmd=keystone-lock' "${hypridle_conf}"
grep -Fxq '  on-timeout=keystone-lock' "${hypridle_conf}"
grep -Fxq '  timeout=300' "${hypridle_conf}"
grep -Fxq '  after_sleep_cmd=keystone-dpms-wake || (hyprctl dispatch dpms on && brightnessctl -r)' "${hypridle_conf}"
grep -Fxq '  on-resume=keystone-dpms-wake || (hyprctl dispatch dpms on && brightnessctl -r)' "${hypridle_conf}"
grep -Fxq 'bindl=, switch:on:Lid Switch, exec, keystone-lock --fail-closed && systemctl suspend' "${hyprland_conf}"
! grep -Fq 'pidof hyprlock' "${hypridle_conf}" "${hyprland_conf}"
printf 'ok: lock hooks\n'
