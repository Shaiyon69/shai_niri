#!/bin/sh
# Noctalia post_hook: AdwSteamGtk installs the custom.css Noctalia just rendered, then
# flatten.js re-applies the speed-up (every install undoes it). Steam shows it after a restart.
command -v adwaita-steam-gtk >/dev/null 2>&1 || exit 0
lock="${XDG_RUNTIME_DIR:-/tmp}/shaiyon-steam-apply.lock"
flatten="${XDG_DATA_HOME:-$HOME/.local/share}/steam-adwaita-flatten/flatten.js"
# Background and locked: Noctalia does not wait, and quick theme changes do not overlap.
setsid -f sh -c '
  exec 9>"$1"; flock 9
  adwaita-steam-gtk -i >/dev/null 2>&1 || exit 0
  [ -f "$2" ] && command -v node >/dev/null 2>&1 && node "$2" >/dev/null 2>&1
' sh "$lock" "$flatten" >/dev/null 2>&1
