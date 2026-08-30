#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
before="$(git -C "${repo_dir}" status --porcelain=v1 --untracked-files=all)"

for script in "${repo_dir}/install.sh" "${repo_dir}"/tests/*.sh; do
  bash -n "${script}"
done

"${repo_dir}/tests/stow-worktrees.sh"
"${repo_dir}/tests/fleet-packages.sh"

after="$(git -C "${repo_dir}" status --porcelain=v1 --untracked-files=all)"
if [[ "${after}" != "${before}" ]]; then
  printf 'Tests changed the dotfiles worktree.\n' >&2
  diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
  exit 1
fi

printf 'ok: worktree status unchanged\n'
