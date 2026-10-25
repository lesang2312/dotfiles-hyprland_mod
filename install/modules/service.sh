#!/usr/bin/env bash
# =============================================================================
#  service.sh — âm thanh (PipeWire) và Bluetooth, nhận diện init system
# =============================================================================

detect_init_system() {
    if [[ -d /run/systemd/system ]] || have systemctl; then echo systemd
    elif have openrc-init || [[ -d /run/openrc ]]; then echo openrc
    elif have dinitctl; then echo dinit
    else echo generic; fi
}

_ensure_user_bus() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
    [[ -S "$XDG_RUNTIME_DIR/bus" ]]
}

comp_audio() {
    pm_install_many "${AUDIO_PKGS[@]}" || return 1

    if _ensure_user_bus || (( DRY_RUN )); then
        log_info "Bật dịch vụ PipeWire (user)…"
        run systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service \
            || log_warn "Không bật được dịch vụ âm thanh — sẽ tự chạy ở lần đăng nhập sau."
    else
        log_warn "Không có phiên D-Bus của user — PipeWire sẽ tự khởi động sau khi đăng nhập."
    fi

    log_info "Bỏ tắt tiếng và đặt âm lượng 80%…"
    run_quiet sudo alsactl init || true
    run_quiet amixer sset Master unmute || true
    run_quiet amixer sset Master 80% || true
    if have wpctl && (_ensure_user_bus || (( DRY_RUN ))); then
        run_quiet wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
        run_quiet wpctl set-volume @DEFAULT_AUDIO_SINK@ 80% || true
    fi
}

_append_as_root() {   # _append_as_root <file> (nội dung từ stdin)
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s nối thêm vào %s\n' "$C_DIM" "$C_RESET" "$1"; cat >/dev/null
    else
        sudo tee -a "$1" >/dev/null
    fi
}

comp_bluetooth() {
    pm_install_many "${BLUETOOTH_PKGS[@]}" || return 1

    local conf=/etc/bluetooth/main.conf
    log_info "Cấu hình Bluetooth tự bật khi khởi động…"
    run sudo mkdir -p /etc/bluetooth || return 1
    if [[ -f "$conf" ]]; then
        if grep -qE '^[#[:space:]]*AutoEnable[[:space:]]*=' "$conf"; then
            run sudo sed -i -E 's/^[#[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable=true/' "$conf" || return 1
        elif grep -q '^\[Policy\]' "$conf"; then
            run sudo sed -i '/^\[Policy\]/a AutoEnable=true' "$conf" || return 1
        else
            printf '\n[Policy]\nAutoEnable=true\n' | _append_as_root "$conf" || return 1
        fi
    else
        printf '[Policy]\nAutoEnable=true\n' | _append_as_root "$conf" || return 1
    fi
    run sudo systemctl enable --now bluetooth.service || return 1
    run sudo systemctl restart bluetooth.service || log_warn "Không restart được bluetooth.service."
}
