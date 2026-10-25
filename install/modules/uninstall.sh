# shellcheck shell=bash
# =============================================================================
#  uninstall.sh — gỡ những gì installer đã chép (KHÔNG gỡ gói đã cài)
# =============================================================================

do_uninstall() {
    [[ -f "$MANIFEST_FILE" ]] || die "Không tìm thấy manifest ($MANIFEST_FILE) — chưa cài hoặc đã gỡ."

    printf '%sCác mục sẽ bị xoá:%s\n' "$C_BOLD" "$C_RESET"
    sed 's/^/  - /' "$MANIFEST_FILE"
    [[ -d "$BIGBLUE_DIR" ]] && printf '  - %s\n' "$BIGBLUE_DIR"
    printf '\n%sCác gói (pacman/AUR) sẽ được GIỮ NGUYÊN.%s\n\n' "$C_DIM" "$C_RESET"
    confirm "Tiếp tục gỡ?" n || { log_info "Đã huỷ."; return 0; }

    sudo_keepalive_start
    local p
    while IFS= read -r p; do
        [[ -n "$p" && "$p" == "$HOME"/* ]] || continue     # chỉ xoá trong $HOME
        run rm -rf -- "$p" || log_warn "Không xoá được $p"
        # dọn thư mục cha nếu đã rỗng (environment.d, autostart, fcitx5…)
        run_quiet rmdir --ignore-fail-on-non-empty -- "$(dirname "$p")" || true
    done <"$MANIFEST_FILE"

    if [[ -d "$BIGBLUE_DIR" ]]; then
        run sudo rm -rf -- "$BIGBLUE_DIR" || true
        run sudo fc-cache -f || true
    fi

    # bản cũ nhất = trạng thái của bạn trước khi cài lần đầu
    if [[ -n "$(list_backups)" ]] && confirm "Khôi phục cấu hình gốc (bản sao lưu đầu tiên, trước khi cài)?" y; then
        restore_backup oldest || true
    fi

    run rm -f -- "$MANIFEST_FILE" "$VERSION_FILE"
    log_ok "Đã gỡ $APP_TITLE."
}
