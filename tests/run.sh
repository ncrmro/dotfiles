#!/usr/bin/env bash
# Requirements: Bash 3.2+, Git 2.31+, GNU Stow/coreutils, Zsh, and ssh-agent.
# By default the Hyprland suite also needs Nix plus network access or populated
# store paths for pinned Hyprland and Lua 5.4 builds. Set both HYPRLAND_BIN and
# LUA_BIN to compatible local executables to skip those builds; HYPRLAND_BIN
# must still report the pinned version and revision.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
before="$(git -C "${repo_dir}" status --porcelain=v1 --untracked-files=all)"

for script in "${repo_dir}/install.sh" "${repo_dir}"/tests/*.sh; do
  bash -n "${script}"
done

test "$(grep -Ec '^trap .* EXIT$' "${repo_dir}/tests/fleet-packages.sh")" -eq 1
if grep -Fq 'trap - EXIT' "${repo_dir}/tests/fleet-packages.sh"; then
  printf 'Fleet tests disable their process-wide cleanup trap.\n' >&2
  exit 1
fi
if grep -En '^[[:space:]]*![[:space:]]' "${repo_dir}"/tests/*.sh; then
  printf 'Tests contain a bare negated assertion.\n' >&2
  exit 1
fi
if grep -Eq 'match\([^)]*,[^)]*,' "${repo_dir}/tests/fleet-packages.sh"; then
  printf 'Fleet tests contain a non-portable three-argument awk match.\n' >&2
  exit 1
fi
if grep -En 'm[a]pfile|read[a]rray|-p[r]intf|[(]realp[a]th[[:space:]]|sha256s[u]m|sort -[z]|-print[0]|mktemp[[:space:]]+-d[)]' \
  "${repo_dir}"/tests/*.sh; then
  printf 'Tests contain an unselected GNU command or a Bash-newer-than-3.2 primitive.\n' >&2
  exit 1
fi

"${repo_dir}/tests/stow-worktrees.sh"
"${repo_dir}/tests/fleet-packages.sh"

after="$(git -C "${repo_dir}" status --porcelain=v1 --untracked-files=all)"
if [[ "${after}" != "${before}" ]]; then
  printf 'Tests changed the dotfiles worktree.\n' >&2
  diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
  exit 1
fi

printf 'ok: worktree status unchanged\n'
