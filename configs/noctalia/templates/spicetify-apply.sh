#!/bin/sh
# Noctalia post_hook: Spicetify bakes the new color.ini into Spotify. Spotify shows it after a restart.
command -v spicetify >/dev/null 2>&1 || exit 0
theme="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/Themes/Noctalia"
# Spicetify needs a user.css next to color.ini; colors all come from color.ini.
[ -f "$theme/user.css" ] || printf '/* Colors come from color.ini, which Noctalia generates. */\n' > "$theme/user.css"
setsid -f spicetify -q -n refresh >/dev/null 2>&1
