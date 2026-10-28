local ok, S = pcall(require, "settings")
if not ok or type(S) ~= "table" then S = {} end

if S.config then
    -- hl.config rejects plugin keys, thanks for nothing
    local core = {}
    for k, v in pairs(S.config) do
        if k ~= "plugin" then core[k] = v end
    end
    hl.config(core)

    local glass = S.config.plugin and S.config.plugin.hyprglass
    if glass then
        local function apply_glass()
            if hl.plugin and hl.plugin.hyprglass then
                hl.plugin.hyprglass.config(glass)
                return true
            end
            return false
        end
        if not apply_glass() then
            hl.on("hyprland.start", apply_glass)
        end
    end
end

local QUICKSHELL_LAYERS = table.concat({
    "quickshell-bar", "settings-panel", "settings-panel-outside", "app-drawer",
    "music-player", "notification-popup", "osd", "home-screen", "boot-sequence", "profile-switcher",
}, ",")
local targets = S.hyprglass
if targets and (targets.layers ~= nil or targets.quickshell ~= nil) then
    local layers = targets.layers ~= false
    local quickshell = targets.quickshell ~= false
    local function apply_targets()
        if not (hl.plugin and hl.plugin.hyprglass) then return false end
        hl.plugin.hyprglass.config({ layers = {
            enabled = layers or quickshell,
            namespaces = (quickshell and not layers) and QUICKSHELL_LAYERS or "",
            exclude_namespaces = (layers and not quickshell) and QUICKSHELL_LAYERS or "",
        } })
        return true
    end
    if not apply_targets() then
        hl.on("hyprland.start", apply_targets)
    end
end

-- also copied into dark/light so they don't win. i think
local look = S.glass
local base = package.loaded.hyprglass
if look and type(base) == "table" and hl.plugin and hl.plugin.hyprglass then
    local values = { dark = {}, light = {} }
    for k, v in pairs(look) do
        values[k] = v
        values.dark[k] = v
        values.light[k] = v
    end
    hl.plugin.hyprglass.preset(base.preset, values)
end

local A = S.animation
if A and A.curve then
    local mult = math.max(0.1, tonumber(A.speed) or 1)
    local windowStyle = A.window or "popin 90%"
    local workspaceStyle = A.workspace or "slide"
    hl.curve("panel", { type = "bezier", points = { { A.curve[1], A.curve[2] }, { A.curve[3], A.curve[4] } } })
    local leaves = {
        { "windows", 4, windowStyle },
        { "windowsOut", 3.5, windowStyle },
        { "windowsMove", 3 },
        { "fade", 4 },
        { "border", 6 },
        { "workspaces", 4, workspaceStyle },
        { "specialWorkspace", 4, workspaceStyle },
        { "layers", 3, "popin 80%" },
    }
    for _, leaf in ipairs(leaves) do
        hl.animation({ leaf = leaf[1], enabled = true, speed = leaf[2] / mult, bezier = "panel", style = leaf[3] })
    end
end

local B = S.border
if B and B.gradient then
    local colors = {}
    local file = io.open(os.getenv("HOME") .. "/.cache/wal/colors-hyprland", "r")
    if file then
        for line in file:lines() do
            local idx, hex = line:match("%$color(%d+)%s*=%s*0x%x%x(%x%x%x%x%x%x)")
            if idx then colors[tonumber(idx)] = "rgba(" .. hex .. "ff)" end
        end
        file:close()
    end
    local PALETTES = {
        accent = { 9, 13 },
        ocean = { 9, 12, 14 },
        ember = { 1, 3 },
        aurora = { 2, 6, 4 },
        sunset = { 1, 5, 13 },
        glow = { 9, 15 },
    }
    local stops = {}
    for _, i in ipairs(PALETTES[B.palette] or PALETTES.accent) do
        if colors[i] then stops[#stops + 1] = colors[i] end
    end
    if #stops == 1 then stops[2] = stops[1] end
    if #stops >= 2 then
        hl.config({ general = { col = { active_border = { colors = stops, angle = B.angle or 45 } } } })
    end
end

if S.mice and S.config and S.config.input and S.config.input.sensitivity ~= nil then
    for _, name in ipairs(S.mice) do
        hl.device({ name = name, sensitivity = S.config.input.sensitivity })
    end
end
