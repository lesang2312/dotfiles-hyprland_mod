# shellcheck shell=bash
# =============================================================================
#  sddm.sh — màn hình đăng nhập SDDM với theme "cartoon" (lấy từ repo cartoon-shell)
#  Chạy SAU thành phần `shell` (cần thư mục theme đã được clone) và sau `wallpapers`.
#  LƯU Ý: dùng `|| return 1` cho lệnh quan trọng (xem deps.sh).
# =============================================================================

# Ảnh đầu tiên (sắp xếp theo tên) trong ~/Pictures/Wallpapers — giống ảnh mà shell sẽ tự đặt ở lần chạy đầu
_sddm_first_wallpaper() {
    local dir
    dir="$(pictures_dir)/Wallpapers"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort -f | head -n 1
}

comp_sddm() {
    local src="$SHELL_TARGET_DIR/$SDDM_THEME_SRC_SUBDIR"
    local dest="$SDDM_THEMES_DIR/$SDDM_THEME_NAME"

    pm_install_many "${SDDM_PKGS[@]}" || return 1

    if ! (( DRY_RUN )) && [[ ! -f "$src/Main.qml" ]]; then
        log_error "Repo cartoon-shell chưa có theme SDDM ($SDDM_THEME_SRC_SUBDIR) — hãy cập nhật repo shell."
        return 1
    fi

    # ---- chép theme (chép đè, giữ lại file 'wallpaper' do shell đồng bộ) ----
    log_info "Cài theme SDDM '$SDDM_THEME_NAME' → $dest"
    run sudo mkdir -p "$dest" || return 1
    run sudo cp -rf "$src"/. "$dest"/ || return 1
    run sudo find "$dest" -type d -exec chmod 755 {} + || return 1
    run sudo find "$dest" -type f -exec chmod 644 {} + || return 1
    # user sở hữu thư mục theme để cartoon-shell chép hình nền hiện tại sang mà không cần sudo
    run sudo chown "$(id -un)" "$dest" || log_warn "Không đổi được chủ sở hữu $dest — hình nền đăng nhập sẽ không tự đồng bộ."
    [[ -f "$dest/wallpaper" ]] && { run sudo chown "$(id -un)" "$dest/wallpaper" || true; }

    # ---- ảnh nền đăng nhập ban đầu = hình nền đầu tiên ----
    if ! (( DRY_RUN )) && [[ ! -f "$dest/wallpaper" ]]; then
        local wp
        wp="$(_sddm_first_wallpaper)"
        if [[ -n "$wp" ]]; then
            log_info "Ảnh nền đăng nhập ban đầu: $(basename "$wp")"
            cp -f -- "$wp" "$dest/wallpaper" 2>/dev/null && chmod 644 "$dest/wallpaper" \
                || log_warn "Không chép được ảnh nền đăng nhập (sẽ dùng nền gradient)."
        fi
    fi

    # ---- đặt theme làm mặc định ----
    log_info "Đặt theme '$SDDM_THEME_NAME' làm màn hình đăng nhập → $SDDM_CONF_FILE"
    run sudo mkdir -p "$(dirname "$SDDM_CONF_FILE")" || return 1
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s ghi file %s\n' "$C_DIM" "$C_RESET" "$SDDM_CONF_FILE"
    else
        printf '# Tạo bởi %s installer — xoá file này để trở về theme mặc định\n[Theme]\nCurrent=%s\n' \
            "$APP_TITLE" "$SDDM_THEME_NAME" | sudo tee "$SDDM_CONF_FILE" >/dev/null || return 1
    fi

    # /etc/sddm.conf (nếu có) được đọc SAU conf.d nên sẽ đè theme của ta → sửa luôn dòng Current=
    if [[ -f /etc/sddm.conf ]] && grep -qE '^[[:space:]]*Current=' /etc/sddm.conf; then
        log_info "Cập nhật Current= trong /etc/sddm.conf (đã sao lưu .cartoon-shell.bak)."
        run sudo cp -n /etc/sddm.conf /etc/sddm.conf.cartoon-shell.bak || true
        run sudo sed -i -E "s|^[[:space:]]*Current=.*|Current=${SDDM_THEME_NAME}|" /etc/sddm.conf || return 1
    fi

    # ---- bật dịch vụ (có hiệu lực ở lần khởi động tới; KHÔNG khởi động ngay để khỏi ngắt phiên đang chạy) ----
    case "$(detect_init_system)" in
        systemd)
            # -f: thay thế trình đăng nhập khác (gdm/lightdm…) đang giữ display-manager.service
            run sudo systemctl enable -f sddm.service \
                || { log_error "Không bật được sddm.service."; return 1; }
            ;;
        *)
            log_warn "Init system không phải systemd — hãy tự bật dịch vụ 'sddm' (theme đã được cài)."
            ;;
    esac
    log_ok "SDDM sẵn sàng: màn hình đăng nhập mới sẽ xuất hiện ở lần khởi động lại."
}
