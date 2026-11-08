#!/usr/bin/env bash
#
# shai_niri installer: niri + Noctalia desktop, Alacritty, fish and fastfetch configs.
#
#   curl -fsSL https://raw.githubusercontent.com/Shaiyon69/shai_niri/main/install.sh | bash
#
# To pass options through curl:  ... | bash -s -- --dry-run
#
# Everything lives in functions and main runs on the last line, so a download
# cut off halfway does nothing instead of running half a script.

set -euo pipefail

REPO_URL="${SHAI_NIRI_REPO_URL:-https://github.com/Shaiyon69/shai_niri.git}"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
BACKUP_DIR="$STATE_DIR/shai_niri/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
ASSUME_YES=0
INSTALL_PACKAGES=1
RELOAD=1
LOGIN_THEME=1
ONLY_LOGIN_THEME=0

# Named to load last in sddm.conf.d, so it beats files such as kde_settings.conf.
LOGIN_THEME_DIR="/usr/share/sddm/themes/shai_niri"
LOGIN_THEME_CONF="/etc/sddm.conf.d/zz-shai_niri.conf"

WORK_DIR=""
SOURCE_DIR=""
STAGE_DIR=""
MISSING_PACKAGES=()

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  --dry-run       Show what would change, without changing anything
  --yes           Don't ask for confirmation
  --no-packages   Only install config files, skip pacman
  --no-reload     Don't reload the running desktop
  --no-login-theme      Don't install the SDDM login screen theme
  --only-login-theme    Only install the SDDM login screen theme
  -h, --help      Show this help

Files that get replaced are backed up first, to
~/.local/state/shai_niri/backups/<timestamp>/
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --yes) ASSUME_YES=1 ;;
            --no-packages) INSTALL_PACKAGES=0 ;;
            --no-reload) RELOAD=0 ;;
            --no-login-theme) LOGIN_THEME=0 ;;
            --only-login-theme) ONLY_LOGIN_THEME=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) die "unknown option: $1 (try --help)" ;;
        esac
        shift
    done
}

cleanup() {
    if [ -n "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

os_field() {
    # Prints a field from os-release, or nothing if it's missing.
    (
        # shellcheck disable=SC1091
        . /etc/os-release 2>/dev/null || exit 0
        eval "printf '%s' \"\${$1:-}\""
    )
}

check_system() {
    [ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it uses sudo when needed)"
    command -v pacman >/dev/null 2>&1 || die "this installer needs an Arch-based system (pacman not found)"

    case " $(os_field ID) $(os_field ID_LIKE) " in
        *" arch "* | *" cachyos "*) ;;
        *) warn "this doesn't look like Arch or CachyOS, so packages may not be available" ;;
    esac
}

# Use the files next to this script, or clone the repo when piped from curl.
locate_source() {
    local script="${BASH_SOURCE[0]:-}"
    if [ -n "$script" ] && [ -f "$script" ]; then
        local dir
        dir="$(cd "$(dirname "$script")" && pwd)"
        if [ -d "$dir/configs" ]; then
            SOURCE_DIR="$dir"
            return
        fi
    fi

    if ! command -v git >/dev/null 2>&1; then
        [ "$DRY_RUN" -eq 0 ] || die "git is needed to download the configs; install it or run from a clone"
        info "Installing git to download the configs"
        sudo pacman -S --needed --noconfirm git
    fi

    info "Downloading configs from $REPO_URL"
    git clone --quiet --depth 1 "$REPO_URL" "$WORK_DIR/repo" || die "could not download $REPO_URL"
    SOURCE_DIR="$WORK_DIR/repo"
}

# Build the final files in a temp folder that mirrors where they'll go, so they
# can be validated together before anything on the system is touched.
stage_files() {
    STAGE_DIR="$WORK_DIR/stage"
    mkdir -p "$STAGE_DIR/config" "$STAGE_DIR/state/noctalia" "$STAGE_DIR/data/shai_niri"

    cp -r "$SOURCE_DIR/configs/." "$STAGE_DIR/config/"
    cp -r "$SOURCE_DIR/data/." "$STAGE_DIR/data/"
    cp "$SOURCE_DIR/assets/wallpaper.jpg" "$STAGE_DIR/data/shai_niri/wallpaper.jpg"

    local wallpaper="$DATA_DIR/shai_niri/wallpaper.jpg" escaped
    escaped="$(printf '%s' "$wallpaper" | sed 's/[&|\\]/\\&/g')"
    sed "s|__WALLPAPER__|$escaped|g" "$SOURCE_DIR/templates/noctalia-settings.toml" \
        >"$STAGE_DIR/state/noctalia/settings.toml"

    # Monitor settings belong to the machine, so an existing file always wins.
    local display="$CONFIG_DIR/niri/cfg/display.kdl"
    if [ -f "$display" ]; then
        cp "$display" "$STAGE_DIR/config/niri/cfg/display.kdl"
    fi
}

uses_sddm() {
    local manager
    manager="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    [ "$(basename "$manager")" = "sddm.service" ]
}

# SDDM can't read files in a home folder, so the theme carries its own wallpaper.
stage_login_theme() {
    mkdir -p "$WORK_DIR/login-theme"
    cp "$SOURCE_DIR"/sddm/shai_niri/* "$WORK_DIR/login-theme/"
    cp "$SOURCE_DIR/assets/wallpaper.jpg" "$WORK_DIR/login-theme/wallpaper.jpg"
    printf '[Theme]\nCurrent=shai_niri\n' >"$WORK_DIR/login-theme.conf"
}

login_theme_is_current() {
    diff -r "$WORK_DIR/login-theme" "$LOGIN_THEME_DIR" >/dev/null 2>&1 &&
        cmp -s "$WORK_DIR/login-theme.conf" "$LOGIN_THEME_CONF"
}

show_login_theme_plan() {
    [ "$LOGIN_THEME" -eq 1 ] || return 0
    if ! uses_sddm; then
        info "Login screen: skipped, this system doesn't use SDDM"
    elif login_theme_is_current; then
        info "Login screen: already up to date"
    else
        info "Login screen: install $LOGIN_THEME_DIR and $LOGIN_THEME_CONF (needs sudo)"
    fi
}

# A failure here only warns, because the desktop itself is already installed.
install_login_theme() {
    [ "$LOGIN_THEME" -eq 1 ] || return 0
    uses_sddm || return 0
    login_theme_is_current && return 0

    info "Installing the login screen (sudo may ask for your password)"
    if ! sudo install -Dm644 -t "$LOGIN_THEME_DIR" "$WORK_DIR"/login-theme/* ||
        ! sudo install -Dm644 "$WORK_DIR/login-theme.conf" "$LOGIN_THEME_CONF"; then
        warn "could not install the login screen; run install.sh --only-login-theme to retry"
        return 0
    fi

    # The main config file overrides sddm.conf.d.
    if grep -Eq '^[[:space:]]*Current=.' /etc/sddm.conf 2>/dev/null; then
        warn "/etc/sddm.conf sets its own theme, so remove its Current= line to use this one"
    fi
    info "Login screen installed; it appears the next time SDDM starts"
}

find_missing_packages() {
    local pkg
    local wanted=()
    while read -r pkg; do
        pkg="${pkg%%#*}"
        pkg="${pkg//[[:space:]]/}"
        if [ -n "$pkg" ]; then
            wanted+=("$pkg")
        fi
    done <"$SOURCE_DIR/packages.txt"

    # The fish config loads CachyOS's defaults when they're available.
    if [ "$(os_field ID)" = "cachyos" ]; then
        wanted+=(cachyos-fish-config)
    fi

    MISSING_PACKAGES=()
    for pkg in "${wanted[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done
}

target_for() {
    # Maps a staged path such as config/niri/config.kdl to its real location.
    case "$1" in
        config/*) printf '%s/%s' "$CONFIG_DIR" "${1#config/}" ;;
        state/*) printf '%s/%s' "$STATE_DIR" "${1#state/}" ;;
        data/*) printf '%s/%s' "$DATA_DIR" "${1#data/}" ;;
        *) die "unexpected staged path: $1" ;;
    esac
}

staged_files() {
    (cd "$STAGE_DIR" && find . -type f | sed 's|^\./||' | sort)
}

show_plan() {
    local rel target new=0 changed=0 same=0

    if [ "$INSTALL_PACKAGES" -eq 1 ]; then
        if [ "${#MISSING_PACKAGES[@]}" -gt 0 ]; then
            info "Packages to install: ${MISSING_PACKAGES[*]}"
        else
            info "All packages are already installed"
        fi
    fi

    while read -r rel; do
        target="$(target_for "$rel")"
        if [ ! -e "$target" ]; then
            printf '   new      %s\n' "$target"
            new=$((new + 1))
        elif ! cmp -s "$STAGE_DIR/$rel" "$target"; then
            printf '   replace  %s\n' "$target"
            changed=$((changed + 1))
        else
            same=$((same + 1))
        fi
    done < <(staged_files)

    info "Files: $new new, $changed replaced (backed up first), $same already up to date"
}

confirm() {
    [ "$ASSUME_YES" -eq 0 ] || return 0

    # stdin is the script itself when piped from curl, so ask on the terminal.
    if ! { exec 3</dev/tty; } 2>/dev/null; then
        die "no terminal to ask for confirmation; re-run with --yes"
    fi

    local answer
    printf 'Continue? [y/N] ' >/dev/tty
    read -r answer <&3
    exec 3<&-
    case "$answer" in
        y | Y | yes | YES) ;;
        *) die "cancelled, nothing was changed" ;;
    esac
}

install_packages() {
    [ "$INSTALL_PACKAGES" -eq 1 ] || return 0
    [ "${#MISSING_PACKAGES[@]}" -gt 0 ] || return 0

    info "Installing packages (sudo may ask for your password)"
    if ! sudo pacman -S --needed --noconfirm "${MISSING_PACKAGES[@]}"; then
        die "package install failed and no configs were changed; if your package lists are out of date, run 'sudo pacman -Syu' and try again"
    fi
}

validate_staged() {
    local output

    if command -v niri >/dev/null 2>&1; then
        if ! output="$(niri validate -c "$STAGE_DIR/config/niri/config.kdl" 2>&1)"; then
            printf '%s\n' "$output" >&2
            die "the niri config failed validation, nothing was changed"
        fi
        info "niri config is valid"
    else
        [ "$DRY_RUN" -eq 1 ] || die "niri isn't installed, so the config can't be validated"
        warn "niri isn't installed yet, skipping its validation"
    fi

    if command -v noctalia >/dev/null 2>&1; then
        if ! output="$(noctalia config validate "$STAGE_DIR/config/noctalia/config.toml" 2>&1)"; then
            printf '%s\n' "$output" >&2
            die "the Noctalia config failed validation, nothing was changed"
        fi
        info "Noctalia config is valid"
    else
        [ "$DRY_RUN" -eq 1 ] || die "noctalia isn't installed, so the config can't be validated"
        warn "noctalia isn't installed yet, skipping its validation"
    fi
}

install_files() {
    local rel target backed_up=0

    while read -r rel; do
        target="$(target_for "$rel")"
        if cmp -s "$STAGE_DIR/$rel" "$target"; then
            continue
        fi
        if [ -e "$target" ]; then
            install -Dm644 "$target" "$BACKUP_DIR/$rel"
            backed_up=$((backed_up + 1))
        fi
        install -Dm644 "$STAGE_DIR/$rel" "$target"
    done < <(staged_files)

    mkdir -p "$HOME/Pictures/Screenshots"

    # The presets are already in place, so skip Noctalia's first-run wizard.
    touch "$STATE_DIR/noctalia/.setup-complete"

    if [ "$backed_up" -gt 0 ]; then
        info "Backed up $backed_up replaced file(s) to $BACKUP_DIR"
    fi
}

reload_desktop() {
    [ "$RELOAD" -eq 1 ] || return 0

    # niri watches its own config file. Noctalia needs telling.
    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg config-reload >/dev/null 2>&1 || warn "could not reload Noctalia"
        noctalia msg color-scheme-set custom Soft >/dev/null 2>&1 || warn "could not set the Noctalia theme"
        info "Reloaded Noctalia"
    fi
}

finish() {
    info "Done"
    if [ "$(basename "${SHELL:-}")" != "fish" ]; then
        printf '   To make fish your default shell, run: chsh -s /usr/bin/fish\n'
    fi
    if [ -z "${NIRI_SOCKET:-}" ]; then
        printf '   Log out, then choose niri on your login screen.\n'
    fi
}

main() {
    parse_args "$@"
    check_system

    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT

    locate_source
    stage_login_theme

    if [ "$ONLY_LOGIN_THEME" -eq 1 ]; then
        [ "$LOGIN_THEME" -eq 1 ] || die "--no-login-theme and --only-login-theme can't be used together"
        uses_sddm || die "this system doesn't use SDDM"
        show_login_theme_plan
        if [ "$DRY_RUN" -eq 1 ]; then
            info "Dry run, nothing was changed"
            return
        fi
        login_theme_is_current || confirm
        install_login_theme
        return
    fi

    stage_files
    find_missing_packages
    show_plan
    show_login_theme_plan

    if [ "$DRY_RUN" -eq 1 ]; then
        validate_staged
        info "Dry run, nothing was changed"
        return
    fi

    confirm
    install_packages
    validate_staged
    install_files
    install_login_theme
    reload_desktop
    finish
}

main "$@"
