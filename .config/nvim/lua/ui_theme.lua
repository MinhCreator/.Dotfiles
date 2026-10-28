local M = {}
local state = require("settings_state")

local function refresh_bars()
    vim.cmd("redrawstatus")
    local ok_lualine, lualine = pcall(require, "lualine")
    if ok_lualine and lualine.refresh then
        lualine.refresh({
            place = { "statusline", "tabline", "winbar" },
            trigger = "colorscheme",
        })
    end
end

local function sync_lualine_theme(theme_name)
    local ok_lualine, lualine = pcall(require, "lualine")
    if not ok_lualine or not lualine.get_config or not lualine.setup then
        return
    end

    local cfg = lualine.get_config()
    if not cfg or type(cfg) ~= "table" then
        return
    end

    cfg.options = cfg.options or {}
    cfg.options.theme = theme_name
    lualine.setup(cfg)
end

local function apply_pywal_plugin_overrides()
    local color_bg = vim.g.background or "#000000"
    local color_fg = vim.g.foreground or "#ffffff"
    local color1 = vim.g.color1 or color_fg
    local color5 = vim.g.color5 or color_fg
    local color9 = vim.g.color9 or color_fg

    -- reapply cmdline/noice highlights when switching back to pywal
    vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = color9 })
    vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = color5 })
    -- pywal.nvim doesn't cover neo-tree
    vim.api.nvim_set_hl(0, "NeoTreeNormal", { fg = color_fg, bg = color_bg })
    vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { fg = color_fg, bg = color_bg })
    vim.api.nvim_set_hl(0, "NeoTreeWinSeparator", { fg = color1, bg = color_bg })

    -- pywal.nvim gives keywords, functions and statements all color6 and skips treesitter,
    -- so lay out syntax like the real themes do: one hue per kind, italic keywords
    local c = {}
    for i = 0, 15 do c[i] = vim.g["color" .. i] or color_fg end
    local function mix(a, b, t)
        local x, y = tonumber(a:sub(2), 16), tonumber(b:sub(2), 16)
        local out = 0
        for s = 16, 0, -8 do
            local p, q = math.floor(x / 2 ^ s) % 256, math.floor(y / 2 ^ s) % 256
            out = out * 256 + math.floor(p + (q - p) * t + 0.5)
        end
        return string.format("#%06x", out)
    end
    -- color8 is too dark on some schemes, a gray from the text color always reads
    local gray = mix(color_bg, color_fg, 0.45)
    local subtle = mix(color_bg, color_fg, 0.08)

    for group, spec in pairs({
        Comment = { fg = gray, italic = true },
        ["@comment"] = { link = "Comment" },
        LineNr = { fg = mix(color_bg, color_fg, 0.3) },
        CursorLineNr = { fg = c[11], bold = true },
        CursorLine = { bg = subtle },
        ColorColumn = { bg = subtle },
        Visual = { bg = mix(color_bg, c[4], 0.3) },
        Search = { fg = color_bg, bg = c[2] },
        IncSearch = { fg = color_bg, bg = c[9] },
        MatchParen = { bg = mix(color_bg, color_fg, 0.2), bold = true },

        Keyword = { fg = c[9], italic = true },
        Statement = { fg = c[9], italic = true },
        Conditional = { fg = c[9], italic = true },
        Repeat = { fg = c[9], italic = true },
        Exception = { fg = c[9], italic = true },
        Label = { fg = c[11] },
        Operator = { fg = c[11] },
        Function = { fg = c[12] },
        ["@function.builtin"] = { fg = c[12], italic = true },
        ["@function.call"] = { fg = c[12] },
        ["@function.method"] = { fg = c[12] },
        ["@constructor"] = { fg = c[12] },
        String = { fg = c[10] },
        Character = { fg = c[10] },
        ["@string.escape"] = { fg = c[14] },
        ["@string.regexp"] = { fg = c[14] },
        ["@string.special"] = { fg = c[14] },
        Number = { fg = c[13] },
        Float = { fg = c[13] },
        Boolean = { fg = c[13] },
        Constant = { fg = c[13] },
        ["@constant.builtin"] = { fg = c[13], italic = true },
        Type = { fg = c[11] },
        ["@type.builtin"] = { fg = c[11], italic = true },
        Identifier = { fg = color_fg },
        ["@variable"] = { fg = color_fg },
        ["@variable.builtin"] = { fg = c[14], italic = true },
        ["@variable.parameter"] = { fg = c[14] },
        ["@variable.member"] = { fg = c[14] },
        ["@property"] = { fg = c[14] },
        ["@module"] = { fg = c[11], italic = true },
        PreProc = { fg = c[13], italic = true },
        Include = { fg = c[13], italic = true },
        Define = { fg = c[13], italic = true },
        Special = { fg = c[11] },
        ["@punctuation.special"] = { fg = c[11] },
        ["@punctuation.bracket"] = { fg = gray },
        Delimiter = { fg = gray },
        ["@tag"] = { fg = c[9] },
        ["@tag.attribute"] = { fg = c[11], italic = true },
        Title = { fg = c[9], bold = true },
        ["@markup.heading"] = { link = "Title" },
        ["@markup.link"] = { fg = c[12], underline = true },
        Todo = { fg = color_bg, bg = c[12], bold = true },

        DiagnosticError = { fg = c[9] },
        DiagnosticWarn = { fg = c[11] },
        DiagnosticInfo = { fg = c[12] },
        DiagnosticHint = { fg = c[14] },
        DiffAdd = { bg = mix(color_bg, c[2], 0.2) },
        DiffChange = { bg = mix(color_bg, c[4], 0.2) },
        DiffDelete = { bg = mix(color_bg, c[1], 0.2) },
        GitSignsAdd = { fg = c[10] },
        GitSignsChange = { fg = c[12] },
        GitSignsDelete = { fg = c[9] },
        SnacksIndent = { fg = mix(color_bg, color_fg, 0.12) },
        SnacksIndentScope = { fg = mix(color_bg, color_fg, 0.3) },
    }) do
        vim.api.nvim_set_hl(0, group, spec)
    end
end

local function set_colorscheme(theme)
    local ok, err = pcall(vim.cmd, "colorscheme " .. theme)
    if not ok then
        vim.notify("Theme not available: " .. theme .. " (" .. tostring(err) .. ")", vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.apply_theme(theme)
    if not set_colorscheme(theme) then
        return
    end

    vim.g.current_theme = theme
    state.set("theme", theme)
    sync_lualine_theme("auto")
    refresh_bars()
end

function M.use_pywal()
    vim.cmd("source ~/.cache/wal/colors-wal.vim")

    -- use :colorscheme so ColorScheme listeners fire
    if not set_colorscheme("pywal") then
        -- some pywal.nvim versions only have setup()
        local ok, pywal = pcall(require, "pywal")
        if ok and pywal.setup then
            pywal.setup()
            vim.g.colors_name = "pywal"
            vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "pywal" })
        else
            return
        end
    end

    vim.g.current_theme = "pywal"
    state.set("theme", "pywal")

    -- run after other ColorScheme listeners
    vim.schedule(function()
        apply_pywal_plugin_overrides()
        sync_lualine_theme("pywal-nvim")
        refresh_bars()
    end)
end

function M.init()
    vim.g.current_theme = state.get("theme", "pywal")

    vim.api.nvim_create_user_command("ThemePywal", function()
        M.use_pywal()
    end, { desc = "Use pywal for all highlights" })

    vim.api.nvim_create_user_command("ThemeFileTokyo", function()
        M.apply_theme("tokyonight")
    end, { desc = "Switch full theme to tokyonight" })

    vim.api.nvim_create_user_command("ThemeFileGruvbox", function()
        M.apply_theme("gruvbox")
    end, { desc = "Switch full theme to gruvbox" })

    vim.api.nvim_create_user_command("ThemeFileKanagawa", function()
        M.apply_theme("kanagawa")
    end, { desc = "Switch full theme to kanagawa" })

    vim.api.nvim_create_user_command("ThemeFileCatppuccin", function()
        M.apply_theme("catppuccin-macchiato")
    end, { desc = "Switch full theme to catppuccin macchiato" })

    vim.api.nvim_create_user_command("ThemeFileRosePine", function()
        M.apply_theme("rose-pine")
    end, { desc = "Switch full theme to rose-pine" })

    vim.api.nvim_create_user_command("ThemeFileNord", function()
        M.apply_theme("nord")
    end, { desc = "Switch full theme to nord" })

    vim.api.nvim_create_user_command("ThemeFileEverforest", function()
        M.apply_theme("everforest")
    end, { desc = "Switch full theme to everforest" })

    vim.api.nvim_create_user_command("ThemeFileOneDark", function()
        M.apply_theme("onedark")
    end, { desc = "Switch full theme to onedark" })

    vim.api.nvim_create_user_command("ThemeFileCarbonfox", function()
        M.apply_theme("carbonfox")
    end, { desc = "Switch full theme to carbonfox" })

    vim.api.nvim_create_user_command("ThemeFileGithub", function()
        M.apply_theme("github_dark_dimmed")
    end, { desc = "Switch full theme to github dark dimmed" })

    vim.api.nvim_create_user_command("ThemeFileVSCode", function()
        M.apply_theme("vscode")
    end, { desc = "Switch full theme to vscode" })

    vim.api.nvim_create_user_command("ThemeFileGruvboxMaterial", function()
        M.apply_theme("gruvbox-material")
    end, { desc = "Switch full theme to gruvbox material" })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("ui-theme-refresh-bars", { clear = true }),
        callback = function()
            refresh_bars()
        end,
    })

    vim.schedule(function()
        local startup_theme = state.get("theme", "pywal")
        if startup_theme == "pywal" then
            M.use_pywal()
        else
            M.apply_theme(startup_theme)
        end
    end)
end

return M
