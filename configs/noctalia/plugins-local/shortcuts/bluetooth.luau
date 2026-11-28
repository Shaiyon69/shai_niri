--!nonstrict
-- Bluetooth icon: off, on, or connected. Click opens Home > Bluetooth.
-- No hover label: Noctalia anchors plugin labels to the middle of the pill, not the icon.

local function refresh()
    noctalia.runAsync({ "sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && { bluetoothctl devices Connected | head -n1; echo on; } || echo off" }, function(result)
        local out = tostring(result.stdout or "")
        local glyph = "bluetooth-off"
        if out:find("on%s*$") then
            local device = out:match("^Device %S+ ([^\n]+)")
            glyph = device and "bluetooth-connected" or "bluetooth"
        end
        barWidget.setGlyph(glyph)
    end)
end

function update()
    refresh()
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "bluetooth" })
end

barWidget.setGlyph("bluetooth")
noctalia.setUpdateInterval(5000)
refresh()
