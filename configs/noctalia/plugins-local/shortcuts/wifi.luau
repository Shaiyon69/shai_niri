--!nonstrict
-- Wi-Fi icon that follows signal strength. Noctalia's font draws Wi-Fi as a wedge that fills
-- with the level: wifi-0 (outline) to wifi-3 (full). Ethernet shows network, nothing shows
-- wifi-off. Click opens Home > Network.
-- No hover label: Noctalia anchors plugin labels to the middle of the pill, not the icon.

-- Signal % to icon: 0-24 empty, 25-49 a third, 50-74 two thirds, 75+ full.
local function wifiGlyph(signal)
    if signal >= 75 then
        return "wifi-3"
    elseif signal >= 50 then
        return "wifi-2"
    elseif signal >= 25 then
        return "wifi-1"
    end
    return "wifi-0"
end

local function show(glyph)
    barWidget.setGlyph(glyph)
end

local function refresh()
    noctalia.runAsync({ "nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device" }, function(result)
        local kind
        for line in tostring(result.stdout or ""):gmatch("[^\n]+") do
            local k, state, n = line:match("^([^:]*):([^:]*):(.*)$")
            if state == "connected" and (k == "wifi" or k == "ethernet") then
                kind = k
                break
            end
        end
        if kind == "ethernet" then
            show("network")
        elseif kind ~= "wifi" then
            show("wifi-off")
        else
            -- --rescan no: read the last scan, never trigger a new one every poll.
            noctalia.runAsync({ "nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no" }, function(scan)
                local signal = tonumber(tostring(scan.stdout or ""):match("%*:(%d+)")) or 0
                show(wifiGlyph(signal))
            end)
        end
    end)
end

function update()
    refresh()
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "network" })
end

barWidget.setGlyph("wifi-0")
noctalia.setUpdateInterval(5000)
refresh()
