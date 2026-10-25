#!/usr/bin/env bash
# =============================================================================
#  migrate.sh — sao lưu, khôi phục và di trú từ setup.sh đời cũ
# =============================================================================

BACKUP_DIR=""

# backup_paths <đường dẫn tuyệt đối trong $HOME...>
backup_paths() {
    local -a existing=() rel=()
    local p
    for p in "$@"; do
        [[ -e "$p" || -L "$p" ]] && existing+=("$p")
    done
    if (( ${#existing[@]} == 0 )); then
        log_info "Không có cấu hình cũ cần sao lưu."
        return 0
    fi

    BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    log_info "Sao lưu ${#existing[@]} mục → $BACKUP_DIR"
    run mkdir -p "$BACKUP_DIR/files" || return 1
    for p in "${existing[@]}"; do rel+=("${p#"$HOME"/}"); done

    if (( DRY_RUN )); then
        printf '%s[dry-run]%s sao lưu: %s\n' "$C_DIM" "$C_RESET" "${rel[*]}"
        return 0
    fi
    ( cd "$HOME" && cp -a --parents -- "${rel[@]}" "$BACKUP_DIR/files/" ) || return 1
    printf '%s\n' "${rel[@]}" >"$BACKUP_DIR/manifest"
    log_ok "Đã sao lưu."
}

list_backups() {
    [[ -d "$BACKUP_ROOT" ]] || return 0
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r
}

restore_backup() {
    local name="${1:-}"
    local -a all=()
    mapfile -t all < <(list_backups)
    (( ${#all[@]} )) || die "Chưa có bản sao lưu nào trong $BACKUP_ROOT"

    if [[ "$name" == oldest ]]; then
        name="${all[$((${#all[@]} - 1))]}"      # danh sách xếp mới→cũ, phần tử cuối là bản cũ nhất
    elif [[ -z "$name" ]]; then
        if (( ASSUME_YES || ! INTERACTIVE )); then
            name="${all[0]}"
        else
            printf 'Các bản sao lưu:\n'
            local i
            for i in "${!all[@]}"; do printf '  %d) %s\n' "$((i+1))" "${all[$i]}"; done
            local pick
            read -r -p "Chọn số [1]: " pick </dev/tty || true
            pick="${pick:-1}"
            [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#all[@]} )) || die "Lựa chọn không hợp lệ."
            name="${all[$((pick-1))]}"
        fi
    fi
    local src="$BACKUP_ROOT/$name/files"
    [[ -d "$src" ]] || die "Không tìm thấy bản sao lưu: $name"

    log_info "Khôi phục từ $name …"
    confirm "Ghi đè cấu hình hiện tại bằng bản sao lưu này?" y || return 1
    run cp -a "$src/." "$HOME/" || return 1
    log_ok "Đã khôi phục."
}

# Bản cài đời cũ (setup.sh): sao lưu cấu hình Quickshell cũ, giữ nguyên phần còn lại
migrate_legacy() {
    log_warn "Phát hiện bản cài cũ (setup.sh) — sẽ sao lưu trước khi cài mới."
    pkill -f "quickshell" 2>/dev/null || true
    backup_paths "$SHELL_TARGET_DIR"
}
