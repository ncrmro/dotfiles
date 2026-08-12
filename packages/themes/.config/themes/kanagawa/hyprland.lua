hl.config({ general = { col = { active_border = "rgb(dcd7ba)" } } })

-- Kanagawa's backdrop needs stronger terminal opacity than the base rule.
hl.window_rule({ name = "kanagawa-terminal-opacity", match = { tag = "terminal" }, opacity = "0.98 0.95" })
