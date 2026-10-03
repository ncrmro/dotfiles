#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-wrapper.XXXXXXXXXX")"
trap 'rm -rf "${test_root}"' EXIT
mkdir -p "${test_root}/bin" "${test_root}/home with spaces"
cat >"${test_root}/bin/ks-stow-dotfiles" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${CAPTURE}"
exit "${STUB_STATUS:-0}"
STUB
chmod +x "${test_root}/bin/ks-stow-dotfiles"
export PATH="${test_root}/bin:${PATH}"
export HOME="${test_root}/home with spaces" CAPTURE="${test_root}/arguments"
"${repo_dir}/install.sh"
printf '%s\n' --repo "${repo_dir}" --target "${HOME}" git ssh zsh >"${test_root}/expected"
cmp "${test_root}/expected" "${CAPTURE}"
"${repo_dir}/install.sh" --check themes ssh
printf '%s\n' --repo "${repo_dir}" --target "${HOME}" --check themes ssh >"${test_root}/expected"
cmp "${test_root}/expected" "${CAPTURE}"
if STUB_STATUS=42 "${repo_dir}/install.sh" git; then
  printf 'Wrapper hid installer failure\n' >&2
  exit 1
else
  test "$?" -eq 42
fi
if "${repo_dir}/install.sh" --adopt >"${test_root}/error" 2>&1; then
  printf 'Wrapper accepted an unsupported option\n' >&2
  exit 1
fi
grep -Fq 'Unsupported option: --adopt' "${test_root}/error"
# An isolated PATH proves the error is useful on hosts without Terminal.
rm "${test_root}/bin/ks-stow-dotfiles"
ln -s "$(command -v bash)" "${test_root}/bin/bash"
ln -s "$(command -v dirname)" "${test_root}/bin/dirname"
if PATH="${test_root}/bin" "${repo_dir}/install.sh" >"${test_root}/error" 2>&1; then
  printf 'Wrapper succeeded without the shared installer\n' >&2
  exit 1
fi
grep -Fq 'ks.systems/terminal' "${test_root}/error"
printf 'ok: wrapper defaults, check, failure propagation, and installation guidance\n'
