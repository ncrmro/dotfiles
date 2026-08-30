#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

git clone -q --no-hardlinks "${repo_dir}" "${test_root}/canonical"
git -C "${test_root}/canonical" worktree add -q -b test/sibling "${test_root}/sibling"
# The regression runs before this change is committed, so place the current
# implementation into both disposable checkouts.
cp "${repo_dir}/install.sh" "${test_root}/canonical/install.sh"
cp "${repo_dir}/install.sh" "${test_root}/sibling/install.sh"

assert_target() {
  local target="$1"
  local expected="$2"
  test "$(realpath -m "${target}")" = "$(realpath -m "${expected}")"
}

home="${test_root}/home"
mkdir -p "${home}"
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target "${home}/.config/git/config" "${test_root}/canonical/packages/git/.config/git/config"

# canonical -> worktree: check is non-mutating, install atomically retargets.
before="$(readlink "${home}/.config/git/config")"
HOME="${home}" "${test_root}/sibling/install.sh" --check git
test "$(readlink "${home}/.config/git/config")" = "${before}"
HOME="${home}" "${test_root}/sibling/install.sh" git
assert_target "${home}/.config/git/config" "${test_root}/sibling/packages/git/.config/git/config"

# Unchanged links are accepted, then worktree -> canonical is symmetric.
HOME="${home}" "${test_root}/sibling/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target "${home}/.config/git/config" "${test_root}/canonical/packages/git/.config/git/config"

# An unrelated symlink and a regular file remain hard failures.
rm "${home}/.config/git/config"
ln -s /tmp/unrelated "${home}/.config/git/config"
if HOME="${home}" "${test_root}/canonical/install.sh" --check git 2>/dev/null; then
  echo "unrelated symlink was accepted" >&2
  exit 1
fi
rm "${home}/.config/git/config"
printf 'collision\n' >"${home}/.config/git/config"
if HOME="${home}" "${test_root}/canonical/install.sh" --check git 2>/dev/null; then
  echo "regular-file collision was accepted" >&2
  exit 1
fi

if HOME="${home}" "${test_root}/canonical/install.sh" --check missing 2>/dev/null; then
  echo "missing package was accepted" >&2
  exit 1
fi

echo "ok: sibling worktree transitions"
