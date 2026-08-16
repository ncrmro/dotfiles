local close_binding_path = assert(arg[1], "close binding path is required")

local active_window
local dispatches = {}
local notifications = {}
local callbacks = {}
local bind_count = 0

hl = {
  dsp = {
    window = {
      close = function(options)
        return { action = "close", window = options.window }
      end,
    },
  },
  dispatch = function(dispatcher)
    table.insert(dispatches, dispatcher)
  end,
  get_active_window = function()
    return active_window
  end,
  notification = {
    create = function(options)
      local notification = {
        options = options,
        dismissed = false,
      }
      function notification:dismiss()
        self.dismissed = true
      end
      table.insert(notifications, notification)
      return notification
    end,
  },
  bind = function(keys, callback, options)
    bind_count = bind_count + 1
    assert(keys == "SUPER + W", "unexpected close binding")
    options = options or {}
    if options.long_press then
      callbacks.long_press = callback
      return
    end
    if options.release then
      assert(options.ignore_mods, "release must survive modifier-first release")
      assert(options.non_consuming, "release must not consume plain W")
      callbacks.release = callback
      return
    end
    callbacks.press = callback
  end,
}
mod = "SUPER"

assert(loadfile(close_binding_path))()
assert(callbacks.press and callbacks.long_press and callbacks.release)
assert(bind_count == 3, "close policy must register exactly three bindings")

local function reset_observations(window)
  active_window = window
  dispatches = {}
  notifications = {}
end

reset_observations(nil)
callbacks.press()
assert(#dispatches == 0 and #notifications == 0, "no active window must be a no-op")

local protected_classes = {
  "chromium",
  "chromium-browser",
  "google-chrome",
  "google-chrome-beta",
  "google-chrome-dev",
  "google-chrome-unstable",
}
for _, class in ipairs(protected_classes) do
  local window = { class = class, mapped = true }
  reset_observations(window)
  callbacks.press()
  assert(#dispatches == 0, class .. " must remain open on press")
  assert(#notifications == 1, class .. " must show one notification")
  assert(notifications[1].options.text == "Hold Mod+W to close Chrome")
  assert(notifications[1].options.timeout == 1500)
  callbacks.release()
  assert(notifications[1].dismissed, "release must dismiss the notification")
  callbacks.long_press()
  assert(#dispatches == 0, "release must clear the pending close")
end

for _, class in ipairs({ "chrome-example-Default", "firefox", "ghostty" }) do
  local window = { class = class, mapped = true }
  reset_observations(window)
  callbacks.press()
  assert(#notifications == 0, class .. " must not show a notification")
  assert(#dispatches == 1 and dispatches[1].window == window,
    class .. " must close the exact active window immediately")
end

local saved_window = { class = "chromium", mapped = true }
local focused_window = { class = "ghostty", mapped = true }
reset_observations(saved_window)
callbacks.press()
active_window = focused_window
callbacks.long_press()
assert(#dispatches == 1 and dispatches[1].window == saved_window,
  "long press must close the saved window after focus changes")
assert(notifications[1].dismissed, "long press must dismiss the notification")
assert(#notifications == 1, "long press must not show a success notification")
callbacks.long_press()
assert(#dispatches == 1, "long press must clear the pending close")

local stale_window = { class = "chromium", mapped = true }
local replacement_window = { class = "google-chrome", mapped = true }
reset_observations(stale_window)
callbacks.press()
active_window = replacement_window
callbacks.press()
assert(notifications[1].dismissed, "a new press must dismiss the stale notification")
callbacks.long_press()
assert(#dispatches == 1 and dispatches[1].window == replacement_window,
  "a new press must replace the stale saved window")
assert(#notifications == 2, "a replacement press must show only its required notification")

for _, mutate in ipairs({
  function(window) window.mapped = false end,
  function(window) window.class = "chrome-example-Default" end,
}) do
  local window = { class = "chromium", mapped = true }
  reset_observations(window)
  callbacks.press()
  mutate(window)
  callbacks.long_press()
  assert(#dispatches == 0, "an ineligible saved window must remain open")
  assert(notifications[1].dismissed, "ineligible state must still clear the notification")
end

print("ok: Chrome close callback behavior")
