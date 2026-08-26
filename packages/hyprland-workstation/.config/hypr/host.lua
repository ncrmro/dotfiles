-- ncrmro-workstation: centered master with the first slave on the right.
hl.config({ master = { new_status = "slave", orientation = "center", slave_count_for_center_master = 0, center_master_fallback = "right" } })
