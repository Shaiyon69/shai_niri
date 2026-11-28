-- Opens Home > Network. Never toggles Wi-Fi (the built-in tile does, on a single click).
shortcut.setLabel("Wi-Fi")
shortcut.setIcon("wifi-0")

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "network" })
end
