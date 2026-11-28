-- Opens Home > Bluetooth. Never toggles Bluetooth (the built-in tile does, on a single click).
shortcut.setLabel("Bluetooth")
shortcut.setIcon("bluetooth")

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "bluetooth" })
end
