-- =============================================================================
-- Workspaces
-- Hyprland 0.56.1
-- =============================================================================

------------------------------------------------------------
-- Scratchpad Terminal
------------------------------------------------------------

hl.workspace_rule({
    workspace = "special:scratchpad",

    on_created_empty = "kitty --class kitty-floating",
})

------------------------------------------------------------
-- Obsidian
------------------------------------------------------------

hl.workspace_rule({
    workspace = "special:obsidian",

    on_created_empty = "obsidian",
})

------------------------------------------------------------
-- (Optional) Future workspace rules
------------------------------------------------------------

-- hl.workspace_rule({
--     workspace = "name:web",
--     monitor = "HDMI-A-1",
--     default = true,
-- })
--
-- hl.workspace_rule({
--     workspace = "name:gaming",
--     gaps_in = 0,
--     gaps_out = 0,
-- })
