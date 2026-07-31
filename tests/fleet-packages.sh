#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
desktop=(
  bat btop clipse ghostty helix satty themes walker waybar wofi zellij
  hyprland-common
)

compositions=(
  "maia:git ssh zsh"
  "mercury:git ssh zsh"
  "ocean:git ssh zsh"
  "ncrmro-workstation:git ssh zsh ${desktop[*]} hyprland-workstation"
  "ncrmro-laptop:git ssh zsh ${desktop[*]} hyprland-laptop"
  "ks-test-delltop:git ssh zsh ${desktop[*]} hyprland-delltop"
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
