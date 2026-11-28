--!nonstrict
-- Wi-Fi icon: wifi-0 (Noctalia's outline Wi-Fi; plain "wifi" is a filled wedge) when connected,
-- network on ethernet, wifi-off otherwise. Click opens Home > Network.

local function refresh()
    noctalia.runAsync({ "nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device" }, function(result)
        local glyph, tip = "wifi-off", "Not connected"
        for line in tostring(result.stdout or ""):gmatch("[^\n]+") do
            local kind, state, name = line:match("^([^:]*):([^:]*):(.*)$")
            if state == "connected" and (kind == "wifi" or kind == "ethernet") then
                glyph = kind == "wifi" and "wifi-0" or "network"
                tip = name
                break
            end
        end
        barWidget.setGlyph(glyph)
        barWidget.setTooltip(tip)
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
