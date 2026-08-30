#!/usr/bin/env bash
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
if grep -Eq '^[[:space:]]*![[:space:]]' "${repo_dir}/tests/fleet-packages.sh"; then
  printf 'Fleet tests contain a bare negated assertion.\n' >&2
  exit 1
fi
if grep -Eq 'match\([^)]*,[^)]*,' "${repo_dir}/tests/fleet-packages.sh"; then
  printf 'Fleet tests contain a non-portable three-argument awk match.\n' >&2
  exit 1
fi
if grep -Eq 'sha256sum|sort -z|-print0' "${repo_dir}/tests/stow-worktrees.sh"; then
  printf 'Worktree snapshots depend on GNU-only traversal or hashing.\n' >&2
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
