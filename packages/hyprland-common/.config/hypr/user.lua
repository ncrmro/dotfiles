-- Personal Hyprland overlay. The base config loads this module after the theme.

hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)

local function messaging_rule(name, match)
  match = match or {}
  hl.window_rule({ name = name, match = match, tag = "+messaging" })
end

messaging_rule("signal-messaging", { class = "Signal" })
messaging_rule("whatsapp-messaging", { title = ".*WhatsApp.*" })
messaging_rule("discord-messaging", { class = "discord" })
messaging_rule("telegram-messaging", { class = "telegram" })

hl.window_rule({ name = "private-messaging", match = { tag = "messaging" }, no_screen_share = true, workspace = "special:magic" })
hl.window_rule({ name = "youtube-music-workspace", match = { title = ".*YouTube Music.*" }, workspace = "special:magic" })
