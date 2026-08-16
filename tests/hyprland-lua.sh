#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hyprland_rev="36b2e0cfe0c6094dbc47bd42a437431315bb3087"
if [[ -n "${HYPRLAND_BIN:-}" ]]; then
  hyprland_bin="${HYPRLAND_BIN}"
else
  hyprland_out="$(
    nix build --no-link --print-out-paths \
      "git+https://github.com/hyprwm/Hyprland?rev=${hyprland_rev}&submodules=1#hyprland^out"
  )"
  hyprland_bin="${hyprland_out}/bin/Hyprland"
fi
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
# GNU env treats a Nix path with +date= as an environment assignment.
ln -s "${hyprland_bin}" "${test_root}/Hyprland"
verify_hyprland_bin="${test_root}/Hyprland"

if [[ -n "${LUA_BIN:-}" ]]; then
  lua_bin="${LUA_BIN}"
else
  lua_out="$(nix build --no-link --print-out-paths nixpkgs#lua5_4)"
  lua_bin="${lua_out}/bin/lua"
fi

version_output="$("${hyprland_bin}" --version 2>&1)"
grep -Fq 'Hyprland 0.56.0 ' <<<"${version_output}" \
  && grep -Fq "commit ${hyprland_rev} " <<<"${version_output}" || {
  printf 'Expected Hyprland 0.56.0 at commit %s.\n%s\n' \
    "${hyprland_rev}" "${version_output}" >&2
  exit 1
}

verify_config() {
  local test_home="$1"
  local runtime_dir="$2"

  env -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY \
    HOME="${test_home}" XDG_RUNTIME_DIR="${runtime_dir}" \
    "${verify_hyprland_bin}" --verify-config --i-am-really-stupid \
    --config "${test_home}/.config/hypr/hyprland.lua" 2>&1
}

mapfile -t theme_dirs < <(
  find "${repo_dir}/packages/themes/.config/themes" \
    -mindepth 2 -maxdepth 2 -name hyprland.lua -type f -printf '%h\n' | sort
)
host_packages=(
  hyprland-laptop
  hyprland-delltop
  hyprland-workstation
)

[[ "${#theme_dirs[@]}" -eq 12 ]] || {
  printf 'Expected 12 Hyprland themes. Found %d.\n' "${#theme_dirs[@]}" >&2
  exit 1
}

verified_compositions=0
for host_package in "${host_packages[@]}"; do
  test_home="${test_root}/${host_package}/home"
  runtime_dir="${test_root}/${host_package}/runtime"
  mkdir -p "${test_home}/.config/themes" "${runtime_dir}"
  HOME="${test_home}" "${repo_dir}/install.sh" \
    hyprland-common themes "${host_package}" >/dev/null 2>&1

  for theme_dir in "${theme_dirs[@]}"; do
    theme="${theme_dir##*/}"
    ln -sfn "${theme_dir}" "${test_home}/.config/themes/current"

    if ! output="$(verify_config "${test_home}" "${runtime_dir}")"; then
      printf 'Hyprland rejected host %s with theme %s.\n%s\n' \
        "${host_package}" "${theme}" "${output}" >&2
      exit 1
    fi
    grep -Fq 'config ok' <<<"${output}" || {
      printf 'Hyprland did not confirm host %s with theme %s.\n%s\n' \
        "${host_package}" "${theme}" "${output}" >&2
      exit 1
    }
    verified_compositions=$((verified_compositions + 1))
  done
done
printf 'ok: %d valid Hyprland host-theme compositions\n' "${verified_compositions}"

test_home="${test_root}/negative/home"
runtime_dir="${test_root}/negative/runtime"
mkdir -p "${test_home}/.config/themes" "${runtime_dir}"
HOME="${test_home}" "${repo_dir}/install.sh" \
  hyprland-common themes hyprland-laptop >/dev/null 2>&1

mkdir "${test_root}/broken-theme"
printf 'this is not Lua\n' >"${test_root}/broken-theme/hyprland.lua"
ln -s "${test_root}/broken-theme" "${test_home}/.config/themes/current"

theme_output="$(verify_config "${test_home}" "${runtime_dir}")"
grep -Fq 'Hyprland skipped theme' <<<"${theme_output}"
grep -Fq 'config ok' <<<"${theme_output}"
printf 'ok: invalid theme is isolated\n'

rm "${test_home}/.config/hypr/host.lua"
printf 'error("broken host")\n' >"${test_home}/.config/hypr/host.lua"

if host_output="$(verify_config "${test_home}" "${runtime_dir}")"; then
  printf 'Hyprland accepted an invalid host module.\n' >&2
  exit 1
fi
grep -Fq 'require("host"):' <<<"${host_output}"
grep -Fq 'broken host' <<<"${host_output}"
! grep -Fq 'config ok' <<<"${host_output}"
printf 'ok: invalid host is a diagnosed config error\n'

close_binding="${test_root}/chrome-hold-close.lua"
awk '
  /^local protected_browser_classes = {/ { capture = 1 }
  /^hl.bind\("CTRL \+ ALT \+ DELETE"/ { capture = 0 }
  capture
' "${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.lua" \
  >"${close_binding}"
test "$(grep -Ec '^  \["[^"]+"\] = true,$' "${close_binding}")" -eq 6
! grep -Fq 'hl.bind(mod .. " + W", hl.dsp.window.close())' \
  "${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.lua"
! grep -Eq 'walker|mako|notify-send|exec\(|os\.execute|io\.popen' \
  "${close_binding}"
"${lua_bin}" "${repo_dir}/tests/hyprland-close.lua" "${close_binding}"
