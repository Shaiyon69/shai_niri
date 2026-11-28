-- Local addition (shaiyon): control center tile that opens the Gamer Mode panel.
shortcut.setLabel("Gamer Mode")
shortcut.setIcon("device-gamepad-2")

function onClick()
    noctalia.togglePanel("nomadcxx/gamer-mode:main")
end
