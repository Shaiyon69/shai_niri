# shai_niri

My [niri](https://github.com/YaLTeR/niri) desktop with the [Noctalia](https://noctalia.dev) shell, plus Alacritty, fish and fastfetch configs.

Works on CachyOS and Arch.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Shaiyon69/shai_niri/main/install.sh | bash
```

To see what it would change first:

```sh
curl -fsSL https://raw.githubusercontent.com/Shaiyon69/shai_niri/main/install.sh | bash -s -- --dry-run
```

Then log out and choose niri on your login screen.

## What it does

1. Installs the packages in `packages.txt`.
2. Validates the configs, and stops without changing anything if they fail.
3. Backs up each file it replaces to `~/.local/state/shai_niri/backups/<timestamp>/`.
4. Copies the configs into place, and marks Noctalia's first-run wizard as done.
5. Installs the login screen theme, if your system uses SDDM.

It's safe to run again, which is also how you update.

## Good to know

- **Replaced files:** your niri, Noctalia, Alacritty, fastfetch, MangoHud, `config.fish` and `fish_prompt.fish` configs are replaced, and Noctalia's `settings.toml` too.
- **Discord overlay:** `discover_overlay/config.ini` styles [Discover Overlay](https://github.com/trigg/Discover), which isn't installed for you. Replacing that file logs it out of Discord, so authorize it again on next start. `Mod+N` shows or hides names.
- **Monitor settings:** an existing `~/.config/niri/cfg/display.kdl` is kept. Otherwise edit that file for your monitor, using `niri msg outputs`.
- **Gaming:** FreeSync turns on only while a Steam game window (`steam_app_*`) is on screen. Add `variable-refresh-rate on-demand=true` to your own `display.kdl` if it was kept. MangoHud loads in every Vulkan game, hidden; `Right Shift + F12` shows it. Restart Steam after install so games pick up `MANGOHUD=1`.
- **Cursor and icons:** the cursor is [Bibata Modern Ice](https://github.com/ful1e5/Bibata_Cursor), which isn't in the Arch repos, so it isn't installed for you. Extract `Bibata-Modern-Ice.tar.xz` from its releases into `~/.local/share/icons/`. Icons are Papirus-Dark; GTK apps need `gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark` and `gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice`.
- **Default shell:** this isn't changed. To use fish, run `chsh -s /usr/bin/fish`.
- **Login screen:** other login managers are left alone. To undo the theme, run `sudo rm /etc/sddm.conf.d/zz-shai_niri.conf`.
- **Tailscale:** the launcher gets a Tailscale on/off entry that keeps your own DNS, so tailnet names won't resolve. It's hidden unless Tailscale is installed. First run `sudo tailscale up --operator=$USER`.
- **Laptops:** the bar has no battery or brightness widgets. Add `"battery"` and `"brightness"` to `end` in `~/.config/noctalia/config.toml`.

## Options

| Option | What it does |
|---|---|
| `--dry-run` | Shows what would change, without changing anything |
| `--yes` | Doesn't ask for confirmation |
| `--no-packages` | Only installs config files |
| `--no-reload` | Doesn't reload the running desktop |
| `--no-login-theme` | Doesn't install the login screen theme |
| `--only-login-theme` | Only installs the login screen theme |
