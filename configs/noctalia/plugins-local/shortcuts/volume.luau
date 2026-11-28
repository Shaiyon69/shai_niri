--!nonstrict
-- Volume icon by level. Click opens Home > Audio, scroll changes volume, right-click mutes.

local SINK = "@DEFAULT_AUDIO_SINK@"

local function refresh()
    noctalia.runAsync({ "wpctl", "get-volume", SINK }, function(result)
        local out = tostring(result.stdout or "")
        local level = tonumber(out:match("Volume:%s*([%d%.]+)")) or 0
        local muted = out:find("MUTED") ~= nil
        local glyph = "volume"
        if muted then
            glyph = "volume-off"
        elseif level <= 0 then
            glyph = "volume-3"
        elseif level < 0.5 then
            glyph = "volume-2"
        end
        barWidget.setGlyph(glyph)
        barWidget.setTooltip(muted and "Muted" or string.format("Volume %d%%", math.floor(level * 100 + 0.5)))
    end)
end

function update()
    refresh()
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "audio" })
end

function onRightClick()
    noctalia.runAsync({ "wpctl", "set-mute", SINK, "toggle" }, refresh)
end

function onScroll(axis, steps)
    if axis ~= "vertical" or steps == 0 then
        return
    end
    -- Negative steps are wheel-up: louder. Capped at 100%.
    local change = steps < 0 and "5%+" or "5%-"
    noctalia.runAsync({ "wpctl", "set-volume", "-l", "1.0", SINK, change }, refresh)
end

barWidget.setGlyph("volume")
noctalia.setUpdateInterval(2000)
refresh()
