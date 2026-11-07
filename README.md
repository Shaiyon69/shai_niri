# shai_niri

My [niri](https://github.com/YaLTeR/niri) desktop with the [Noctalia](https://noctalia.dev) shell, plus Alacritty and fish configs.

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

It's safe to run again, which is also how you update.

## Good to know

- **Replaced files:** your niri, Noctalia, Alacritty and `config.fish` configs are replaced, and Noctalia's `settings.toml` too.
- **Monitor settings:** an existing `~/.config/niri/cfg/display.kdl` is kept. Otherwise edit that file for your monitor, using `niri msg outputs`.
- **Default shell:** this isn't changed. To use fish, run `chsh -s /usr/bin/fish`.
- **Laptops:** the bar has no battery or brightness widgets. Add `"battery"` and `"brightness"` to `end` in `~/.config/noctalia/config.toml`.

## Options

| Option | What it does |
|---|---|
| `--dry-run` | Shows what would change, without changing anything |
| `--yes` | Doesn't ask for confirmation |
| `--no-packages` | Only installs config files |
| `--no-reload` | Doesn't reload the running desktop |
