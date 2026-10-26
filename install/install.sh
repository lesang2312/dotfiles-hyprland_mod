#!/usr/bin/env bash
# =============================================================================
#  Cartoon Shell — bộ cài đặt        Xem: ./install/install.sh --help
# =============================================================================

RAW_SLUG="${REPO_SLUG:-lesang2312/dotfiles-hyprland_mod}"      # <-- repo chứa bộ cài này
REPO_SLUG="$(printf '%s' "$RAW_SLUG" | tr -d '\r\n\t ' | sed 's/[^a-zA-Z0-9_\/.-]//g')"
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/cartoon-shell-installer"
export REPO_SLUG

# Chạy từ bản đã giải nén → dùng luôn; chạy qua curl|bash → clone về cache
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    INSTALL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    PROJECT_ROOT="$(dirname "$INSTALL_DIR")"
else
    INSTALL_DIR=""
    PROJECT_ROOT=""
fi

if [[ -z "$PROJECT_ROOT" || ! -f "$PROJECT_ROOT/install/modules/deps.sh" ]]; then
    if [[ "$REPO_SLUG" == YOUR_GITHUB_USER/* ]]; then
        echo "Chưa cấu hình repo: đặt REPO_SLUG=user/repo hoặc sửa RAW_SLUG trong install.sh" >&2
        exit 1
    fi
    if ! command -v git &>/dev/null; then
        command -v pacman &>/dev/null && sudo pacman -Sy --noconfirm --needed git
    fi
    if [ ! -d "$CACHE_BASE/.git" ]; then
        rm -rf "$CACHE_BASE"; mkdir -p "$CACHE_BASE"
        git clone --depth 1 "https://github.com/${REPO_SLUG}.git" "$CACHE_BASE"
    else
        git -C "$CACHE_BASE" remote set-url origin "https://github.com/${REPO_SLUG}.git" 2>/dev/null || true
        git -C "$CACHE_BASE" fetch --depth 1 origin 2>/dev/null || true
        git -C "$CACHE_BASE" reset --hard origin/HEAD 2>/dev/null \
            || git -C "$CACHE_BASE" reset --hard origin/main 2>/dev/null \
            || git -C "$CACHE_BASE" reset --hard origin/master 2>/dev/null || true
    fi
    INSTALL_DIR="$CACHE_BASE/install"
    PROJECT_ROOT="$CACHE_BASE"
fi
export PROJECT_ROOT

MODULES_DIR="$INSTALL_DIR/modules"

# shellcheck source=install/app.conf
source "$INSTALL_DIR/app.conf"
for m in core pm deps state migrate deploy version config service sddm ui components uninstall; do
    # shellcheck source=/dev/null
    source "$MODULES_DIR/$m.sh"
done

OS_NAME=""
INSTALL_STATE="fresh"
TARGET_VERSION="$(get_target_version "$PROJECT_ROOT")"
TARGET_COMMIT="$(get_target_commit "$PROJECT_ROOT")"

usage() {
    cat <<USAGE
${C_BOLD}$APP_TITLE installer v$TARGET_VERSION${C_RESET}

Dùng:  ./install/install.sh [tuỳ chọn]

  -y, --yes             Không hỏi, dùng lựa chọn mặc định (chạy tự động)
      --dry-run         Chỉ in các lệnh sẽ chạy, không thay đổi hệ thống
      --only a,b,c      Chỉ cài các thành phần này (+ thành phần bắt buộc)
      --skip a,b,c      Bỏ qua các thành phần này
      --list            Liệt kê thành phần
      --restore [tên]   Khôi phục cấu hình từ bản sao lưu (mặc định: mới nhất)
      --uninstall       Gỡ file/cấu hình đã chép (giữ nguyên các gói)
      --no-color        Tắt màu
  -v, --version         Hiện phiên bản
  -h, --help            Trợ giúp
USAGE
}

main() {
    local mode=install only="" skip="" restore_name=""

    while (( $# )); do
        case "$1" in
            -y|--yes)     ASSUME_YES=1 ;;
            --dry-run)    DRY_RUN=1 ;;
            --only)       only="${2:?--only cần giá trị}"; shift ;;
            --skip)       skip="${2:?--skip cần giá trị}"; shift ;;
            --list)       mode=list ;;
            --restore)    mode=restore
                          if [[ "${2:-}" && "${2:0:1}" != "-" ]]; then restore_name="$2"; shift; fi ;;
            --uninstall)  mode=uninstall ;;
            --no-color)   NO_COLOR=1; core_init_colors ;;
            -v|--version) echo "$APP_TITLE installer $TARGET_VERSION ($TARGET_COMMIT)"; exit 0 ;;
            -h|--help)    usage; exit 0 ;;
            *)            echo "Tuỳ chọn không hợp lệ: $1 (xem --help)" >&2; exit 2 ;;
        esac
        shift
    done

    core_install_traps
    register_all_components
    if [[ "$mode" == list ]]; then print_component_list; exit 0; fi

    ui_init
    check_supported_os
    log_init
    acquire_lock
    _log_file "START mode=$mode dry=$DRY_RUN yes=$ASSUME_YES only=$only skip=$skip"

    case "$mode" in
        restore)   restore_backup "$restore_name"; exit 0 ;;
        uninstall) do_uninstall; exit 0 ;;
    esac

    INSTALL_STATE="$(detect_install_state)"
    OLD_VERSION="$(get_installed_version)"
    ui_collect_sysinfo
    apply_selection_flags "$only" "$skip"
    # Chọn thành phần; trả lời "n" ở bước xác nhận sẽ quay lại menu chọn
    while true; do
        ui_select_components
        STEP_TOTAL=$(( $(enabled_count) + 2 ))     # + sao lưu + hoàn tất
        ui_show_plan
        if [[ "${COMP_ENABLED[hyprland]}" != 1 && "${COMP_ENABLED[niri]}" != 1 ]]; then
            log_warn "Chưa chọn compositor nào (hyprland / niri) — sẽ không cài compositor và không chép cấu hình hypr/niri."
        fi
        confirm "Bắt đầu cài đặt?" y && break
        (( INTERACTIVE )) || { log_info "Đã huỷ."; exit 0; }
        log_info "Quay lại phần chọn thành phần…"
        sleep 1
    done

    sudo_keepalive_start
    suppress_tty_sleep
    bootstrap_installer_deps

    dotfiles_prepare

    # ---- Sao lưu / di trú ----
    step_begin "Sao lưu cấu hình hiện có"
    if [[ "$INSTALL_STATE" == legacy ]]; then
        migrate_legacy
    fi
    local -a targets=() n
    if [[ "${COMP_ENABLED[dotfiles]}" == 1 ]]; then
        while IFS= read -r n; do targets+=("$HOME/.config/$n"); done < <(dotfiles_top_entries)
    fi
    [[ "${COMP_ENABLED[shell]}" == 1 ]] && targets+=("$SHELL_TARGET_DIR")
    if [[ "${COMP_ENABLED[input]}" == 1 ]]; then
        targets+=("$HOME/.config/environment.d/fcitx5.conf" "$HOME/.config/autostart/fcitx5.desktop" "$HOME/.config/fcitx5/profile")
    fi
    if [[ "$INSTALL_STATE" != legacy ]]; then backup_paths "${targets[@]}"; fi

    # ---- Chạy từng thành phần ----
    local id
    for id in "${COMP_IDS[@]}"; do
        if [[ "${COMP_ENABLED[$id]}" != 1 ]]; then COMP_STATUS[$id]=skipped; continue; fi
        step_begin "${COMP_LABEL[$id]}"
        if "${COMP_FUNC[$id]}"; then
            COMP_STATUS[$id]=ok
        else
            COMP_STATUS[$id]=failed
            log_error "Thành phần '${COMP_LABEL[$id]}' gặp lỗi."
            if [[ "${COMP_REQUIRED[$id]}" == 1 ]]; then
                die "Thành phần bắt buộc thất bại — dừng cài đặt. Xem log: ${LOG_FILE:-n/a}"
            fi
        fi
    done

    step_begin "Hoàn tất"
    install_fonts_refresh_cache
    write_version_state "$TARGET_VERSION" "$TARGET_COMMIT" "$(enabled_list)"

    draw_completion_screen
    ui_ask_reboot
}

main "$@"
