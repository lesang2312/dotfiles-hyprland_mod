#!/usr/bin/env bash
# =============================================================================
#  config.sh — cấu hình bộ gõ tiếng Việt fcitx5 + Unikey, icon theme Papirus-Dark
# =============================================================================

# Cài Papirus và đặt làm icon theme mặc định (tương đương:
#   gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark")
comp_icons() {
    pm_install_many "${ICON_PKGS[@]}" || return 1

    if (( DRY_RUN )); then
        log_info "(dry-run) gsettings set org.gnome.desktop.interface icon-theme $ICON_THEME_NAME"
        return 0
    fi
    if ! have gsettings; then
        HINTS+=("Không có gsettings — chạy sau khi cài glib2:  gsettings set org.gnome.desktop.interface icon-theme \"$ICON_THEME_NAME\"")
        return 0
    fi

    log_info "Đặt icon theme: $ICON_THEME_NAME"
    local schema=org.gnome.desktop.interface
    if gsettings set "$schema" icon-theme "$ICON_THEME_NAME" 2>/dev/null; then
        :
    elif have dbus-run-session && dbus-run-session -- gsettings set "$schema" icon-theme "$ICON_THEME_NAME" 2>/dev/null; then
        :
    else
        HINTS+=("Chưa đặt được icon theme (không có phiên D-Bus). Chạy trong Hyprland:  gsettings set $schema icon-theme \"$ICON_THEME_NAME\"")
        return 0
    fi
    log_ok "Đã đặt icon theme $ICON_THEME_NAME"
}

comp_input() {
    pm_install_many "${INPUT_PKGS[@]}" || return 1

    local envf="$HOME/.config/environment.d/fcitx5.conf"
    local auto="$HOME/.config/autostart/fcitx5.desktop"
    local prof="$HOME/.config/fcitx5/profile"

    log_info "Thiết lập biến môi trường fcitx5…"
    write_file "$envf" <<'CONF' || return 1
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
CONF
    manifest_add "$envf"

    write_file "$auto" <<'CONF' || return 1
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
NoDisplay=true
CONF
    manifest_add "$auto"

    # Hồ sơ mặc định (US + Unikey) — chỉ tạo khi người dùng chưa có
    if [[ ! -f "$prof" ]]; then
        write_file "$prof" <<'CONF' || return 1
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=unikey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
CONF
        manifest_add "$prof"
    fi

    # xdg-autostart không chạy trong Hyprland nếu không có dex/uwsm → nhắc exec-once
    if ! grep -rqs 'fcitx5' "$HOME/.config/hypr" 2>/dev/null; then
        HINTS+=("Thêm vào hyprland.conf để fcitx5 tự chạy:  exec-once = fcitx5 -d")
    fi
}
