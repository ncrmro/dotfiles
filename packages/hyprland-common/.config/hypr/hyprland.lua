local mod = "SUPER"
local app = "uwsm app -- "

hl.config({
  animations = { enabled = true },
  cursor = { no_hardware_cursors = 1 },
  decoration = {
    rounding = 4,
    blur = { enabled = true, passes = 2, size = 5, vibrancy = 0.1696 },
    shadow = { color = "rgba(00000045)", enabled = false, range = 30, render_power = 3 },
  },
  dwindle = { force_split = 2, preserve_split = true },
  ecosystem = { no_update_news = true },
  general = { layout = "master" },
  input = {
    follow_mouse = 1,
    kb_layout = "us",
    kb_options = "ctrl:nocaps,altwin:swap_alt_win",
    scroll_factor = 0.4,
    sensitivity = 0,
    touchpad = { drag_lock = 0, natural_scroll = true },
  },
  master = { new_status = "master" },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_watchdog_warning = true,
    force_default_wallpaper = 0,
    -- These settings are the only DPMS-off recovery path that does not depend
    -- on hypridle's on-resume hook or the lid-open bind below. A wedged connector
    -- still needs keystone-dpms-wake; input alone cannot re-enable it.
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },
  xwayland = { force_zero_scaling = true },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = false, speed = 0, bezier = "ease" })

local function exec(command)
  return hl.dsp.exec_cmd(command)
end

hl.bind(mod .. " + Return", exec(app .. "ghostty"))
hl.bind(mod .. " + Space", exec(app .. "walker"))
hl.bind(mod .. " + B", exec(app .. "chromium --new-window --ozone-platform=wayland"))
hl.bind(mod .. " + E", exec(app .. "nautilus --new-window"))
hl.bind(mod .. " + Escape", exec(app .. "keystone-menu system"))
hl.bind(mod .. " + K", exec(app .. "keystone-menu-keybindings"))

local protected_browser_classes = {
  ["chromium"] = true,
  ["chromium-browser"] = true,
  ["google-chrome"] = true,
  ["google-chrome-beta"] = true,
  ["google-chrome-dev"] = true,
  ["google-chrome-unstable"] = true,
}
local pending_close_window
local pending_close_notification

local function clear_pending_close()
  if pending_close_notification then
    pending_close_notification:dismiss()
  end
  pending_close_window = nil
  pending_close_notification = nil
end

local function close_window_on_press()
  clear_pending_close()

  local window = hl.get_active_window()
  if not window then
    return
  end

  if protected_browser_classes[window.class] then
    pending_close_window = window
    pending_close_notification = hl.notification.create({
      text = "Hold Mod+W to close Chrome",
      timeout = 1500,
    })
    return
  end

  hl.dispatch(hl.dsp.window.close({ window = window }))
end

local function close_window_on_long_press()
  local window = pending_close_window
  if window and window.mapped and protected_browser_classes[window.class] then
    hl.dispatch(hl.dsp.window.close({ window = window }))
  end
  clear_pending_close()
end

local function close_window_on_release()
  clear_pending_close()
end

hl.bind(mod .. " + W", close_window_on_press)
hl.bind(mod .. " + W", close_window_on_long_press, { long_press = true })
hl.bind(mod .. " + W", close_window_on_release, {
  release = true,
  ignore_mods = true,
  non_consuming = true,
})
hl.bind("CTRL + ALT + DELETE", hl.dsp.window.close({ window = "address:.*" }))
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + T", hl.dsp.layout("togglesplit"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(mod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
  hl.bind(mod .. " + SHIFT + " .. direction, hl.dsp.window.swap({ direction = direction }))
end

for workspace = 1, 10 do
  local key = workspace % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mod .. " + SHIFT + period", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mod .. " + backslash", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("ALT + TAB", hl.dsp.window.cycle_next({ next = true }))
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.bring_to_top())
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind("SHIFT + F11", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("ALT + F11", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
hl.bind(mod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }))
hl.bind(mod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))
hl.bind(mod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }))
hl.bind(mod .. " + CTRL + V", exec(app .. "ghostty --class clipse -e clipse"))
hl.bind(mod .. " + CTRL + E", exec(app .. "walker -m symbols"))
hl.bind(mod .. " + SHIFT + Space", exec("killall -SIGUSR1 waybar"))
hl.bind(mod .. " + Backspace", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }))
hl.bind(mod .. " + SHIFT + N", exec("makoctl dismiss"))
hl.bind(mod .. " + ALT + N", exec("makoctl dismiss --all"))
hl.bind(mod .. " + CTRL + SHIFT + N", exec("makoctl mode -t do-not-disturb"))
hl.bind("Print", exec(app .. "keystone-screenshot"))
hl.bind("SHIFT + Print", exec(app .. "keystone-screenshot smart clipboard"))
hl.bind(mod .. " + Print", exec(app .. "hyprpicker -a"))
hl.bind(mod .. " + CTRL + I", exec("keystone-idle-toggle"))
hl.bind(mod .. " + CTRL + N", exec("keystone-nightlight-toggle"))
hl.bind(mod .. " + slash", exec(app .. "keystone-window-switch"))

hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", exec("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
hl.bind("XF86PowerOff", exec(app .. "keystone-menu system"), { locked = true })
hl.bind("switch:on:Lid Switch", exec("keystone-suspend --lid"), { locked = true })
hl.bind("switch:off:Lid Switch", function()
  -- Delay DPMS for 500 ms so Hyprland 0.56 can finish the lid switch callback.
  hl.timer(function()
    hl.dispatch(hl.dsp.dpms({ action = "on" }))
  end, { timeout = 500, type = "oneshot" })
end, { locked = true })
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.layer_rule({ name = "slurp-no-animation", match = { namespace = "slurp" }, no_anim = true })

local function window_rule(name, match, effects)
  effects.name = name
  effects.match = match
  hl.window_rule(effects)
end

window_rule("chromium-tile", { class = "^(chromium)$" }, { tile = true })
window_rule("settings-float", { class = "^(org.pulseaudio.pavucontrol|.blueman-manager-wrapped|blueman-manager)$" }, { float = true })
window_rule("default-opacity", { class = ".*" }, { opacity = "0.97 0.9" })
window_rule("youtube-opacity", { class = "^(chromium|google-chrome|google-chrome-unstable)$", title = ".*Youtube.*" }, { opacity = "1 1" })
window_rule("chromium-opacity", { class = "^(chromium|google-chrome|google-chrome-unstable)$" }, { opacity = "1 0.97" })
window_rule("chromium-pwa-opacity", { class = "^(chrome-.*-Default)$" }, { opacity = "0.97 0.9" })
window_rule("youtube-pwa-opacity", { class = "^(chrome-youtube.*-Default)$" }, { opacity = "1 1" })
window_rule("media-opacity", { class = "^(zoom|vlc|org.kde.kdenlive|com.obsproject.Studio)$" }, { opacity = "1 1" })
window_rule("games-opacity", { class = "^(com.libretro.RetroArch|steam)$" }, { opacity = "1 1" })
window_rule("clipse-float", { class = "(clipse)" }, { float = true, size = "622 652" })
window_rule("notes-inbox", { class = "^(com.mitchellh.ghostty)$", title = "^(keystone-notes-inbox)$" }, { float = true, center = true, size = "1000 700" })
window_rule("polkit-dialog", { class = "^$", title = "^(Authentication required)$" }, {
  float = true,
  center = true,
  size = "486 246",
  pin = true,
  opacity = "0.85 0.78",
  rounding = 12,
})

local function customization_error(name, err)
  print("Hyprland skipped " .. name .. ": " .. tostring(err))
end

local home = os.getenv("HOME")
if home then
  local config_home = home .. "/.config"
  local theme_path = config_home .. "/themes/current/hyprland.lua"
  local theme, load_error = loadfile(theme_path)
  if theme then
    local ok, runtime_error = pcall(theme)
    if not ok then
      customization_error("theme " .. theme_path, runtime_error)
    end
  else
    customization_error("theme " .. theme_path, load_error)
  end

  package.path = config_home .. "/hypr/?.lua;" .. package.path
else
  customization_error("theme", "HOME is not set")
end

local function load_module(name)
  if not home then
    customization_error(name .. ".lua", "HOME is not set")
    return
  end

  local ok, err = pcall(require, name)
  if not ok then
    customization_error(name .. ".lua", err)
  end
end

load_module("user")
load_module("host")
