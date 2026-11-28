--!nonstrict
-- Tools panel: one card per plugin panel that used to sit in the bar.

local TOOLS = {
    { label = "LocalSend", note = "Send files to nearby devices", glyph = "send", panel = "0rgl/localsend-plus:panel" },
    { label = "Tailscale", note = "Tailnet, peers, exit nodes", glyph = "network", panel = "davemhammer/tailscale:manager" },
    { label = "Downloads", note = "Video and audio from a link", glyph = "download", panel = "omerfuyar/media-downloader:panel" },
}

local function card(tool)
    return ui.row({
        align = "center",
        gap = 12,
        padding = 12,
        radius = 12,
        fill = "surface_container",
        onClick = function()
            noctalia.togglePanel(tool.panel)
        end,
    }, {
        ui.row({ width = 36, height = 36, radius = 18, align = "center", justify = "center", fill = "primary" }, {
            ui.glyph({ name = tool.glyph, size = 18, color = "on_primary" }),
        }),
        ui.column({ gap = 0, flexGrow = 1 }, {
            ui.label({ text = tool.label, fontWeight = "semibold" }),
            ui.label({ text = tool.note, fontSize = 11, color = "on_surface_variant" }),
        }),
        ui.glyph({ name = "chevron-right", size = 16, color = "on_surface_variant" }),
    })
end

function onOpen()
    local rows = {
        ui.row({ align = "center", gap = 8, paddingH = 4 }, {
            ui.label({ text = "Tools", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "close", variant = "ghost", onClick = function() panel.close() end }),
        }),
    }
    for _, tool in ipairs(TOOLS) do
        rows[#rows + 1] = card(tool)
    end
    panel.render(ui.column({ padding = 16, gap = 10 }, rows))
end
