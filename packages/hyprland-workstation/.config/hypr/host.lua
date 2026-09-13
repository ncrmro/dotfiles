-- ncrmro-workstation: centered master with the first slave on the right.
hl.config({ master = { new_status = "slave", orientation = "center", slave_count_for_center_master = 0, center_master_fallback = "right" } })

-- Ableton's DXVK swapchain loops when resized to the workstation's tiled leaf.
hl.window_rule({
  name = "ableton-bounded-float",
  match = { class = "^(ableton live 12 suite[.]exe)$" },
  float = true,
  center = true,
  size = "1382 2068",
})
