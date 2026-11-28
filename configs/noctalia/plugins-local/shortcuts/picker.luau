--!nonstrict
-- Compact wallpaper picker: images directly in the wallpaper folder, two per row. Click one to set it. "More" opens Noctalia's full picker.

local IMAGE = { jpg = true, jpeg = true, png = true, webp = true, bmp = true, gif = true }
local THUMB_W, THUMB_H = 148, 84
local MAX_IMAGES = 12 -- shortcut: no scrolling, first 12 only; use "More" for the rest

local function isImage(name)
    local ext = name:match("%.([%w]+)$")
    return ext ~= nil and IMAGE[ext:lower()] == true
end

local function folder()
    local dir = noctalia.getSetting("wallpaper.directory")
    if type(dir) ~= "string" or dir == "" then
        dir = "~/Pictures"
    end
    return noctalia.expandPath(dir)
end

local function current()
    local path = noctalia.getSetting("wallpaper.default.path")
    return type(path) == "string" and path or ""
end

local function images()
    local found = {}
    local root = folder()
    for _, name in ipairs(noctalia.listDir(root) or {}) do
        local path = root .. "/" .. name
        -- Top level only: subfolders (Screenshots, photos) are not wallpapers; "More" browses them.
        if isImage(name) then
            found[#found + 1] = path
        end
        if #found >= MAX_IMAGES then
            break
        end
    end
    table.sort(found)
    return found
end

local render

local function thumb(path, selected)
    return ui.image({
        key = path,
        path = path,
        width = THUMB_W,
        height = THUMB_H,
        fit = "cover",
        radius = 10,
        border = selected and "primary" or "outline_variant",
        borderWidth = selected and 2 or 1,
        onClick = function()
            noctalia.setWallpaper(path)
            render()
        end,
    })
end

render = function()
    local list = images()
    local active = current()
    local rows = {}
    for index = 1, #list, 2 do
        local pair = { thumb(list[index], list[index] == active) }
        if list[index + 1] then
            pair[2] = thumb(list[index + 1], list[index + 1] == active)
        end
        rows[#rows + 1] = ui.row({ gap = 10 }, pair)
    end
    if #list == 0 then
        rows[#rows + 1] = ui.label({ text = "No images in " .. folder(), color = "on_surface_variant", fontSize = 11 })
    end

    panel.render(ui.column({ padding = 16, gap = 10 }, {
        ui.row({ align = "center", gap = 8, fill = "surface_container", radius = 12, padding = 10 }, {
            ui.glyph({ name = "photo", size = 18, color = "primary" }),
            ui.label({ text = "Wallpaper", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ text = "More", glyph = "layout-grid", variant = "outline", controlSize = "sm",
                onClick = function() noctalia.togglePanel("wallpaper") end }),
            ui.button({ glyph = "close", variant = "ghost", onClick = function() panel.close() end }),
        }),
        ui.column({ gap = 10, fill = "surface_container", radius = 12, padding = 10 }, rows),
    }))
end

function onOpen()
    render()
end
