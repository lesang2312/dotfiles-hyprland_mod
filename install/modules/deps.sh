#!/usr/bin/env bash
# =============================================================================
#  deps.sh — kiểm tra hệ thống, danh sách gói và cài đặt phụ thuộc/font
#  LƯU Ý: hàm comp_* chạy trong ngữ cảnh `if`, nên `set -e` KHÔNG hiệu lực.
#         Luôn dùng `|| return 1` cho lệnh quan trọng.
# =============================================================================

SUPPORTED_DISTROS=(
    "arch" "endeavouros" "manjaro" "cachyos" "garuda" "arcolinux" "archcraft"
    "artix" "blackarch" "rebornos" "mabox" "blendos" "parch" "biglinux"
    "archlabs" "athena" "xerolinux" "omarchy" "steamos"
)

# ---- Gói cốt lõi (kho chính) ----
REQUIRED_PKGS=(
    "base-devel"
    "git"
    "kitty"
    "brightnessctl"
    "wl-clipboard"
    "nautilus"
    "grim"
    "slurp"
    "jq"
    "matugen"
    "starship"
    "fish"
    "adw-gtk-theme"
    "bc"
    "ttf-nerd-fonts-symbols"
    "qt6-multimedia"
    "python"
    "xdg-user-dirs"
    "fontconfig"
)

# ---- Compositor: chọn Hyprland và/hoặc niri ----
HYPRLAND_PKGS=(
    "hyprland"
    "xdg-desktop-portal-hyprland"
)
NIRI_PKGS=(
    "niri"
    "xwayland-satellite"
    "xdg-desktop-portal-gnome"
    "xdg-desktop-portal-gtk"
    "gnome-keyring"
)

# ---- Gói AUR ----
AUR_PKGS=(
    "quickshell-git"
    "sysstat"
    "ttf-material-symbols-variable-git"
    "otf-comicshanns-nerd"
    "cava"
    "qt6-5compat"
)

# ---- Icon theme (Papirus-Dark) ----
ICON_PKGS=(
    "papirus-icon-theme"
    "glib2"
    "dconf"
    "gsettings-desktop-schemas"
)
ICON_THEME_NAME="${ICON_THEME_NAME:-Papirus-Dark}"

# ---- Âm thanh ----
AUDIO_PKGS=(
    "alsa-utils"
    "pipewire"
    "pipewire-pulse"
    "pipewire-alsa"
    "pipewire-jack"
    "wireplumber"
    "pavucontrol"
)

# ---- Bluetooth ----
BLUETOOTH_PKGS=(
    "bluez"
    "bluez-utils"
    "blueman"
)

# ---- Bộ gõ tiếng Việt ----
INPUT_PKGS=(
    "fcitx5"
    "fcitx5-gtk"
    "fcitx5-qt"
    "fcitx5-configtool"
    "fcitx5-unikey"
)

# ---- Font cơ bản ----
FONT_PKGS=(
    "noto-fonts"
    "noto-fonts-cjk"
    "noto-fonts-extra"
    "noto-fonts-emoji"
    "ttf-liberation"
    "ttf-dejavu"
    "ttf-droid"
    "gnu-free-fonts"
    "adobe-source-sans-fonts"
    "adobe-source-serif-fonts"
    "adobe-source-code-pro-fonts"
    "ttf-jetbrains-mono"
    "ttf-fira-code"
    "ttf-fira-sans"
    "ttf-roboto"
    "ttf-roboto-mono"
    "ttf-ubuntu-font-family"
    "ttf-opensans"
    "cantarell-fonts"
    "ttf-carlito"
    "ttf-caladea"
    "ttf-hack"
    "ttf-inconsolata"
    "ttf-anonymous-pro"
    "ttf-cascadia-code"
    "ttf-cascadia-mono"
    "ttf-ibm-plex"
    "ttf-linux-libertine"
    "ttf-gentium-basic"
    "encodings"
)

# ---- Font mở rộng AUR (NẶNG — tắt bằng --skip fonts-extra) ----
FONT_EXTRA_PKGS=(
    "ttf-google-fonts-git"
    "ttf-ms-fonts"
    "ttf-ancient-fonts"
    "ttf-unifont"
    "otf-eb-garamond"
    "ttf-lato"
    "ttf-merriweather"
    "ttf-oswald"
    "ttf-raleway"
    "ttf-cormorant"
    "ttf-crimson-pro"
    "ttf-playfair-display"
)

NERD_FONTS_GROUP="nerd-fonts"
FONTS_TOUCHED=0

# ---------------------------------------------------------------------------
#  Kiểm tra hệ thống
# ---------------------------------------------------------------------------
check_supported_os() {
    log_info "Kiểm tra môi trường…"

    if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
        die "Cần bash >= 4.4 (hiện tại ${BASH_VERSION})."
    fi

    # không chạy bằng root (makepkg từ chối root, config sẽ rơi vào /root)
    if (( EUID == 0 )) && (( DRY_RUN )); then
        log_warn "Đang chạy bằng root — chỉ chấp nhận trong --dry-run."
    elif (( EUID == 0 )); then
        die "Đừng chạy bằng root/sudo. Hãy chạy bằng user thường — installer sẽ tự gọi sudo khi cần."
    fi

    local id="" like=""
    if [[ -r /etc/os-release ]]; then
        id="$(. /etc/os-release; echo "${ID:-}")"
        like="$(. /etc/os-release; echo "${ID_LIKE:-}")"
        OS_NAME="$(. /etc/os-release; echo "${PRETTY_NAME:-$id}")"
    fi
    OS_NAME="${OS_NAME:-Linux}"

    local ok=0 d
    for d in "${SUPPORTED_DISTROS[@]}"; do [[ "$id" == "$d" ]] && ok=1; done
    [[ " $like " == *" arch "* ]] && ok=1
    have pacman && ok=1
    if (( ! ok )); then
        if (( DRY_RUN )); then
            log_warn "Không phải Arch ($OS_NAME) — --dry-run vẫn tiếp tục để xem trước."
        else
            die "Installer chỉ hỗ trợ Arch Linux và bản phái sinh (phát hiện: $OS_NAME)."
        fi
    fi

    have flock || die "Thiếu 'flock' (util-linux)."

    if ! (( DRY_RUN )); then
        if ! curl -fsI --max-time 8 https://archlinux.org >/dev/null 2>&1 \
           && ! curl -fsI --max-time 8 https://github.com >/dev/null 2>&1; then
            die "Không có kết nối Internet."
        fi
    fi

    local free_mb
    free_mb="$(df -Pm / 2>/dev/null | awk 'NR==2{print $4}')"
    if [[ -n "$free_mb" ]] && (( free_mb < MIN_FREE_MB )); then
        log_warn "Dung lượng trống ở / chỉ ${free_mb} MB (khuyến nghị ≥ ${MIN_FREE_MB} MB)."
        confirm "Vẫn tiếp tục?" n || exit 1
    fi
    log_ok "Môi trường hợp lệ: $OS_NAME"
}

bootstrap_installer_deps() {
    pm_prepare_repos || true
    local missing=() tool
    for tool in "${PM_BOOTSTRAP_TOOLS[@]}"; do
        have "$tool" || missing+=("$tool")
    done
    if (( ${#missing[@]} )); then
        log_info "Cài công cụ nền: ${missing[*]}"
        pm_bootstrap_install "${missing[@]}" || die "Không cài được công cụ nền."
    fi
}

suppress_tty_sleep() {
    setterm -blank 0 -powerdown 0 2>/dev/null || true
    printf '\033[9;0]' 2>/dev/null || true
}

# ---------------------------------------------------------------------------
#  Các thành phần cài gói
# ---------------------------------------------------------------------------
comp_upgrade() {
    pm_enable_multilib || return 1
    pm_full_upgrade    || return 1
}

comp_core() {
    pm_install_many "${REQUIRED_PKGS[@]}" || return 1
}

comp_hyprland() {
    pm_install_many "${HYPRLAND_PKGS[@]}" || return 1
    if ! (( DRY_RUN )) && ! pm_is_installed hyprland; then
        log_error "Gói 'hyprland' chưa được cài."
        return 1
    fi
}

comp_niri() {
    pm_install_many "${NIRI_PKGS[@]}" || return 1
    if ! (( DRY_RUN )) && ! pm_is_installed niri; then
        log_error "Gói 'niri' chưa được cài."
        return 1
    fi
}

comp_aur() {
    pm_ensure_aur_helper || return 1
    pm_install_many "${AUR_PKGS[@]}"
}

comp_fonts()       { FONTS_TOUCHED=1; pm_install_many "${FONT_PKGS[@]}"; }

comp_fonts_nerd() {
    FONTS_TOUCHED=1
    log_info "Cài trọn bộ Nerd Fonts (dung lượng lớn, có thể mất vài phút)…"
    if pm_group_exists "$NERD_FONTS_GROUP"; then
        run sudo pacman -S --needed --noconfirm "$NERD_FONTS_GROUP" \
            || { FAILED_PKGS+=("$NERD_FONTS_GROUP"); return 0; }
    else
        log_warn "Không có nhóm '$NERD_FONTS_GROUP' trong kho chính — thử qua AUR."
        pm_ensure_aur_helper || return 1
        _pm_aur_install nerd-fonts-complete || FAILED_PKGS+=("nerd-fonts-complete")
    fi
}

comp_fonts_extra() {
    FONTS_TOUCHED=1
    pm_ensure_aur_helper || return 1
    pm_install_many "${FONT_EXTRA_PKGS[@]}"
}

comp_fonts_bigblue() {
    FONTS_TOUCHED=1
    pm_install_many unzip curl || return 1
    local tmp zip
    tmp="$(mktemp -d)"; zip="$tmp/BigBlueTerminal.zip"

    log_info "Tải BigBlue Terminal Nerd Font…"
    if ! run curl -fL# --connect-timeout 15 --retry 3 "$BIGBLUE_URL" -o "$zip"; then
        rm -rf "$tmp"; log_error "Không tải được font từ $BIGBLUE_URL"; return 1
    fi
    if ! (( DRY_RUN )) && ! unzip -tq "$zip" >/dev/null 2>&1; then
        rm -rf "$tmp"; log_error "File tải về không phải zip hợp lệ."; return 1
    fi

    run unzip -qo "$zip" -d "$tmp/x" || { rm -rf "$tmp"; return 1; }
    if ! (( DRY_RUN )); then
        mkdir -p "$tmp/fonts"
        find "$tmp/x" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f -t "$tmp/fonts" {} +
    fi
    run sudo mkdir -p "$BIGBLUE_DIR" || { rm -rf "$tmp"; return 1; }
    if ! (( DRY_RUN )) && ! compgen -G "$tmp/fonts/*" >/dev/null; then
        rm -rf "$tmp"; log_error "Gói font không chứa file .ttf/.otf."; return 1
    fi
    run sudo cp -f "$tmp"/fonts/* "$BIGBLUE_DIR"/ || { rm -rf "$tmp"; return 1; }
    run sudo chmod 644 "$BIGBLUE_DIR"/* || true
    rm -rf "$tmp"
    log_ok "Đã cài BigBlue Terminal Nerd Font → $BIGBLUE_DIR"
}

install_fonts_refresh_cache() {
    (( FONTS_TOUCHED )) || return 0
    log_info "Cập nhật cache font (fc-cache)…"
    run sudo fc-cache -f || log_warn "fc-cache lỗi."
}
