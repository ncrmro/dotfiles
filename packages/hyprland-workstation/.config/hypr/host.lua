-- ncrmro-workstation: Dell U5226KW and centered master layout.
hl.monitor({
  output = "desc:Dell Inc. DELL U5226KW 9XM3884",
  mode = "6144x2560@120.00",
  position = "0x0",
  scale = 1,
  transform = 0,
})

hl.config({ master = { new_status = "slave", orientation = "center", slave_count_for_center_master = 0 } })
