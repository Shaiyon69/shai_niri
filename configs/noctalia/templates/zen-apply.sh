#!/bin/sh
# Noctalia post_hook: copy the generated userChrome.css into each default Zen profile.
# Zen also needs toolkit.legacyUserProfileCustomizations.stylesheets = true in about:config.
src="${XDG_CACHE_HOME:-$HOME/.cache}/shaiyon-theme/zen-userChrome.css"
[ -f "$src" ] || exit 0
for profile in "${XDG_CONFIG_HOME:-$HOME/.config}"/zen/*.Default\ \(release\); do
    [ -d "$profile" ] || continue
    mkdir -p "$profile/chrome"
    cp "$src" "$profile/chrome/userChrome.css"
done
