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

seed_obsolete_stow_link() {
  local source="$1"
  local target="$2"

  ln -s "$(realpath -m --relative-to="$(dirname "${target}")" "${source}")" \
    "${target}"
}

for composition in "${compositions[@]}"; do
  host="${composition%%:*}"
  read -r -a packages <<<"${composition#*:}"
  test_home="$(mktemp -d)"
  trap 'rm -rf "${test_home}"' EXIT

  if [[ " ${packages[*]} " == *" hyprland-common "* ]]; then
    mkdir -p "${test_home}/.config/hypr"
    seed_obsolete_stow_link \
      "${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.conf" \
      "${test_home}/.config/hypr/hyprland.conf"
    seed_obsolete_stow_link \
      "${repo_dir}/packages/hyprland-common/.config/hypr/ncrmro.conf" \
      "${test_home}/.config/hypr/ncrmro.conf"
  fi

  for package in "${packages[@]}"; do
    if [[ "${package}" == hyprland-* && "${package}" != "hyprland-common" ]]; then
      seed_obsolete_stow_link \
        "${repo_dir}/packages/${package}/.config/hypr/host.conf" \
        "${test_home}/.config/hypr/host.conf"
    fi
  done

  HOME="${test_home}" "${repo_dir}/install.sh" "${packages[@]}"
  HOME="${test_home}" "${repo_dir}/install.sh" --check "${packages[@]}"

  if [[ " ${packages[*]} " == *" hyprland-common "* ]]; then
    test -L "${test_home}/.config/hypr/hyprland.lua"
    test -L "${test_home}/.config/hypr/user.lua"
    test -L "${test_home}/.config/uwsm/env"
    test -L "${test_home}/.config/uwsm/env-hyprland"
    ! test -L "${test_home}/.config/hypr/hyprland.conf"
    ! test -L "${test_home}/.config/hypr/ncrmro.conf"
    ! test -L "${test_home}/.config/hypr/host.conf"
    test -L "${test_home}/.config/hypr/host.lua"
  fi

  rm -rf "${test_home}"
  trap - EXIT
  printf 'ok: %s\n' "${host}"
done

themes_dir="${repo_dir}/packages/themes/.config/themes"
mapfile -t theme_dirs < <(find "${themes_dir}" -mindepth 1 -maxdepth 1 -type d | sort)
test "${#theme_dirs[@]}" -eq 15
! find "${themes_dir}" -name zellij.conf -type f | grep -q .
! test -e "${repo_dir}/packages/zellij/.config/zellij/themes/royal-green.kdl"

for theme_dir in "${theme_dirs[@]}"; do
  theme_name="$(basename "${theme_dir}")"
  theme_file="${theme_dir}/zellij.kdl"
  test -f "${theme_file}"
  grep -Eq '^[[:space:]]*current[[:space:]]*\{' "${theme_file}"

  if command -v zellij >/dev/null 2>&1; then
    zellij_home="$(mktemp -d)"
    trap 'rm -rf "${zellij_home}"' EXIT
    mkdir -p "${zellij_home}/.config/zellij/themes"
    ln -s "${repo_dir}/packages/zellij/.config/zellij/config.kdl" \
      "${zellij_home}/.config/zellij/config.kdl"
    ln -s "${theme_file}" \
      "${zellij_home}/.config/zellij/themes/current.kdl"
    HOME="${zellij_home}" \
      XDG_CACHE_HOME="${zellij_home}/.cache" \
      XDG_CONFIG_HOME="${zellij_home}/.config" \
      XDG_DATA_HOME="${zellij_home}/.local/share" \
      XDG_STATE_HOME="${zellij_home}/.local/state" \
      zellij setup --check >/dev/null
    rm -rf "${zellij_home}"
    trap - EXIT
  fi

  printf 'ok: Zellij theme %s\n' "${theme_name}"
done

printf 'ok: Zellij theme contract\n'

hypridle_conf="${repo_dir}/packages/hyprland-common/.config/hypr/hypridle.conf"
hyprland_lua="${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.lua"
uwsm_env="${repo_dir}/packages/hyprland-common/.config/uwsm/env"
uwsm_hyprland_env="${repo_dir}/packages/hyprland-common/.config/uwsm/env-hyprland"

grep -Fxq '  before_sleep_cmd=keystone-lock --fail-closed' "${hypridle_conf}"
grep -Fxq '  inhibit_sleep=3' "${hypridle_conf}"
grep -Fxq '  lock_cmd=keystone-lock' "${hypridle_conf}"
grep -Fxq '  on-timeout=keystone-lock' "${hypridle_conf}"
grep -Fxq '  timeout=300' "${hypridle_conf}"
grep -Fxq '  after_sleep_cmd=keystone-dpms-wake || (hyprctl dispatch dpms on && brightnessctl -r)' "${hypridle_conf}"
grep -Fxq '  on-resume=keystone-dpms-wake || (hyprctl dispatch dpms on && brightnessctl -r)' "${hypridle_conf}"
grep -Fq 'hl.bind("switch:on:Lid Switch", exec("keystone-lock --fail-closed && systemctl suspend")' "${hyprland_lua}"
grep -Fq 'hl.bind("switch:off:Lid Switch", function()' "${hyprland_lua}"
grep -Fq 'hl.timer(function()' "${hyprland_lua}"
grep -Fq 'hl.dispatch(hl.dsp.dpms({ action = "on" }))' "${hyprland_lua}"
! grep -Eq 'hl\.bind\([^\n]*hl\.dsp\.dpms' "${hyprland_lua}"
! grep -Fq 'pidof hyprlock' "${hypridle_conf}" "${hyprland_lua}"
printf 'ok: lock hooks\n'

grep -Fq 'local theme, load_error = loadfile(theme_path)' "${hyprland_lua}"
grep -Fq 'local ok, runtime_error = pcall(theme)' "${hyprland_lua}"
grep -Fq 'local ok, err = pcall(require, name)' "${hyprland_lua}"
grep -Fq 'load_module("user")' "${hyprland_lua}"
grep -Fq 'load_module("host")' "${hyprland_lua}"
grep -Fq 'local app = "uwsm app -- "' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + P", hl.dsp.window.pseudo())' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))' "${hyprland_lua}"
for graphical_command in \
  'ghostty' \
  'chromium --new-window --ozone-platform=wayland' \
  'nautilus --new-window' \
  'keystone-menu system' \
  'keystone-menu-keybindings' \
  'ghostty --class clipse -e clipse' \
  'walker -m symbols' \
  'keystone-screenshot' \
  'keystone-screenshot smart clipboard' \
  'hyprpicker -a' \
  'keystone-window-switch'; do
  grep -Fq "app .. \"${graphical_command}\"" "${hyprland_lua}"
done

! grep -Eq 'systemctl --user import-environment|dbus-update-activation-environment|hyprctl dispatch exit' "${hyprland_lua}"
! grep -Eq 'WLR_RENDERER_ALLOW_SOFTWARE|HYPRCURSOR_' "${uwsm_env}"
! grep -Eq '^[[:space:]]*export[[:space:]]+GTK_THEME=' "${uwsm_env}"
grep -Fxq 'export XDG_DATA_DIRS="${XDG_DATA_DIRS:-$HOME/.local/share:/usr/local/share:/usr/share}:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"' "${uwsm_env}"
grep -Fxq 'export HYPRCURSOR_SIZE=24' "${uwsm_hyprland_env}"
grep -Fxq 'export HYPRCURSOR_THEME=Adwaita' "${uwsm_hyprland_env}"
! grep -Fq 'WLR_RENDERER_ALLOW_SOFTWARE' "${uwsm_hyprland_env}"

test "$(find "${repo_dir}/packages/themes/.config/themes" -name hyprland.lua -type f | wc -l)" -eq 12
! find "${repo_dir}/packages/themes/.config/themes" -name hyprland.conf -type f | grep -q .
! find "${repo_dir}/packages" \( -path '*/hyprland.conf' -o -path '*/ncrmro.conf' -o -path '*/host.conf' \) -type f | grep -q .

for ecosystem_config in hypridle.conf hyprlock.conf hyprpaper.conf hyprsunset.conf xdph.conf; do
  test -f "${repo_dir}/packages/hyprland-common/.config/hypr/${ecosystem_config}"
done
printf 'ok: Hyprland Lua contract\n'

mapfile -t startup_configs < <(
  find "${repo_dir}/packages" -type f \
    \( -path '*/.config/hypr/hyprland.lua' \
    -o -path '*/.config/hypr/user.lua' \
    -o -path '*/.config/hypr/host.lua' \) | sort
)
start_callbacks_are_safe() {
  local file
  for file in "$@"; do
    awk '
      # Contract: hyprland.start callbacks may only perform compositor-local
      # typed dispatch and configuration work. They must not launch a shell,
      # process, GUI, or long-lived service, directly or through a local
      # alias of a Hyprland command dispatcher.
      function unsafe(callback, normalized, remaining, captures, alias, pattern) {
        normalized = callback
        gsub(/[[:space:]]+/, " ", normalized)
        if (normalized ~ /hl[.]exec_(cmd|raw)[[:space:]]*\(/ \
          || normalized ~ /hl[.]dsp[.]exec_(cmd|raw)[[:space:]]*\(/ \
          || normalized ~ /os[.]execute[[:space:]]*\(/ \
          || normalized ~ /io[.]popen[[:space:]]*\(/ \
          || normalized ~ /uwsm[[:space:]]+app/) {
          return 1
        }

        remaining = normalized
        pattern = "(^|[^[:alnum:]_])((local[[:space:]]+)?([[:alpha:]_][[:alnum:]_]*))[[:space:]]*=[[:space:]]*hl[.](dsp[.])?exec_(cmd|raw)([^[:alnum:]_]|$)"
        while (match(remaining, pattern, captures)) {
          alias = captures[4]
          if (normalized ~ ("(^|[^[:alnum:]_])" alias "[[:space:]]*[(]")) {
            return 1
          }
          remaining = substr(remaining, RSTART + RLENGTH)
        }
        return 0
      }

      BEGIN {
        active = 0
        depth = 0
      }

      {
        code = $0
        trimmed = code
        sub(/^[[:space:]]+/, "", trimmed)
        if (!active && trimmed ~ /^--/) {
          next
        }

        if (!active) {
          if (!match(code, /hl[.]on[[:space:]]*\([[:space:]]*["\047]hyprland[.]start["\047]/)) {
            next
          }
          active = 1
          depth = 0
          callback = ""
          code = substr(code, RSTART)
        }

        quote = ""
        escaped = 0
        for (i = 1; i <= length(code); i++) {
          character = substr(code, i, 1)
          following = substr(code, i + 1, 1)

          if (quote == "" && character == "-" && following == "-") {
            break
          }

          callback = callback character
          if (quote != "") {
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
            continue
          }

          if (character == "\"" || character == "\047") {
            quote = character
          } else if (character == "(") {
            depth++
          } else if (character == ")") {
            depth--
            if (depth == 0) {
              if (unsafe(callback)) {
                exit 1
              }
              active = 0
              callback = ""
              break
            }
          }
        }
        callback = callback "\n"
      }

      END {
        if (active) {
          exit 2
        }
      }
    ' "${file}" || return 1
  done
}

start_callbacks_are_safe "${startup_configs[@]}"

callback_test_root="$(mktemp -d)"
trap 'rm -rf "${callback_test_root}"' EXIT
unsafe_fixture="${callback_test_root}/unsafe.lua"
for unsafe_dispatcher in hl.exec_cmd hl.dsp.exec_cmd hl.exec_raw hl.dsp.exec_raw; do
  cat >"${unsafe_fixture}" <<LUA
hl.on("hyprland.start", function()
  local launch = ${unsafe_dispatcher}
  launch("unsafe-example")
end)
LUA
  if start_callbacks_are_safe "${unsafe_fixture}"; then
    printf 'Startup callback guard accepted aliased dispatcher: %s\n' \
      "${unsafe_dispatcher}" >&2
    exit 1
  fi
done
for unsafe_call in \
  'hl.exec_cmd("unsafe-example")' \
  'hl.dsp.exec_cmd("unsafe-example")' \
  'hl.exec_raw("unsafe-example")' \
  'hl.dsp.exec_raw("unsafe-example")' \
  'os.execute("unsafe-example")' \
  'io.popen("unsafe-example")' \
  'local command = "uwsm app -- unsafe-example"'; do
  printf 'hl.on("hyprland.start", function()\n  %s\nend)\n' "${unsafe_call}" \
    >"${unsafe_fixture}"
  if start_callbacks_are_safe "${unsafe_fixture}"; then
    printf 'Startup callback guard accepted unsafe call: %s\n' "${unsafe_call}" >&2
    exit 1
  fi
done

safe_fixture="${callback_test_root}/safe.lua"
cat >"${safe_fixture}" <<'LUA'
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)
LUA
start_callbacks_are_safe "${safe_fixture}"
rm -rf "${callback_test_root}"
trap - EXIT
printf 'ok: active startup callbacks are compositor-local\n'

HYPRLAND_BIN="${HYPRLAND_BIN:-}" "${repo_dir}/tests/hyprland-lua.sh"
