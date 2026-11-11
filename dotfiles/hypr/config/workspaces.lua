-- =============================================================================
-- Workspaces
-- Hyprland 0.56.1
-- =============================================================================

------------------------------------------------------------
-- Special workspaces: spawn app when workspace is created empty
------------------------------------------------------------

local on_created_empty = {
    ["special:scratchpad"] = "kitty --class kitty-floating",
    ["special:obsidian"] = "obsidian",
}

hl.on("workspace.created", function(ws)
    local cmd = on_created_empty[ws.name]
    if cmd and ws.is_empty then
        hl.exec_cmd(cmd)
    end
end)

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
