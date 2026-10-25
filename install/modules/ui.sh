# shellcheck shell=bash
# =============================================================================
#  ui.sh — banner, menu chọn thành phần (bash thuần), màn hình tổng kết
# =============================================================================

UI_FD=0
HINTS=()
SYS_CPU=""; SYS_GPU=""

ui_init() {
    # Có TTY thật thì mới tương tác (kể cả khi chạy qua `curl | bash` nhờ /dev/tty)
    if [[ -t 0 && -t 1 ]]; then
        INTERACTIVE=1; UI_FD=0
    elif [[ -t 1 ]] && { exec 3</dev/tty; } 2>/dev/null; then
        INTERACTIVE=1; UI_FD=3
    else
        INTERACTIVE=0
    fi
    (( ASSUME_YES )) && INTERACTIVE=0
    return 0
}

ui_collect_sysinfo() {
    SYS_CPU="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || true)"
    SYS_GPU="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//' | xargs || true)"
    SYS_CPU="${SYS_CPU:-không rõ}"; SYS_GPU="${SYS_GPU:-không rõ}"
}

read_key() {
    local k rest=""
    IFS= read -rsn1 -u "$UI_FD" k || { echo QUIT; return 0; }
    if [[ "$k" == $'\e' ]]; then
        IFS= read -rsn2 -t 0.05 -u "$UI_FD" rest || true
        case "$rest" in
            '[A'|'OA') echo UP ;;
            '[B'|'OB') echo DOWN ;;
            *)         echo ESC ;;
        esac
        return 0
    fi
    case "$k" in
        '') echo ENTER ;;
        ' ') echo SPACE ;;
        *)  echo "$k" ;;
    esac
}

# confirm "Câu hỏi" [y|n]  → 0 nếu đồng ý
confirm() {
    local msg="$1" def="${2:-y}" ans hint="[Y/n]"
    [[ "$def" == n ]] && hint="[y/N]"
    if (( ASSUME_YES )); then return 0; fi
    if (( ! INTERACTIVE )); then [[ "$def" == y ]]; return; fi
    printf '%s%s?%s %s %s ' "$C_BOLD" "$C_YELLOW" "$C_RESET" "$msg" "$hint"
    IFS= read -r -u "$UI_FD" ans || ans=""
    ans="${ans:-$def}"
    [[ "$ans" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

draw_banner() {
    local line="────────────────────────────────────────────────────────────────────────"
    printf '%s%s' "$C_BOLD" "$C_CYAN"
    cat <<'ART'
   ____    _    ____ _____ ___   ___  _   _
  / ___|  / \  |  _ \_   _/ _ \ / _ \| \ | |
 | |     / _ \ | |_) || || | | | | | |  \| |
 | |___ / ___ \|  _ < | || |_| | |_| | |\  |
  \____/_/   \_\_| \_\|_| \___/ \___/|_| \_|   S H E L L
ART
    printf '%s\n' "$C_RESET"
    printf '%s%s%s\n' "$C_BLUE" "$line" "$C_RESET"
    printf ' %sNgười dùng%s %-18s %sHệ điều hành%s %s\n' "$C_BOLD" "$C_RESET" "${USER:-$(id -un)}" "$C_BOLD" "$C_RESET" "$OS_NAME"
    printf ' %sCPU%s        %s\n' "$C_BOLD" "$C_RESET" "$SYS_CPU"
    printf ' %sGPU%s        %s\n' "$C_BOLD" "$C_RESET" "$SYS_GPU"
    printf '%s%s%s\n' "$C_BLUE" "$line" "$C_RESET"
    local dry=""
    if (( DRY_RUN )); then dry="  ${C_YELLOW}[DRY-RUN]${C_RESET}"; fi
    printf ' %sPhiên bản%s  %s   %sChế độ%s %s%s\n' "$C_BOLD" "$C_RESET" "$TARGET_VERSION" "$C_BOLD" "$C_RESET" \
        "$INSTALL_STATE" "$dry"
    printf '%s%s%s\n\n' "$C_BLUE" "$line" "$C_RESET"
}

_weight_tag() {
    case "$1" in
        nặng) printf '%s[nặng]%s' "$C_RED" "$C_RESET" ;;
        vừa)  printf '%s[vừa ]%s' "$C_YELLOW" "$C_RESET" ;;
        *)    printf '%s[nhẹ ]%s' "$C_GREEN" "$C_RESET" ;;
    esac
}

_draw_menu() {
    local cur="$1" i id box ptr
    printf '\e[H\e[2J'
    draw_banner
    printf '%sChọn thành phần cần cài%s  %s(↑/↓ di chuyển · Space bật/tắt · a tất cả · n bỏ hết · Enter bắt đầu · q thoát)%s\n\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
    for i in "${!COMP_IDS[@]}"; do
        id="${COMP_IDS[$i]}"
        ptr="  "; (( i == cur )) && ptr="${C_CYAN}❯ ${C_RESET}"
        if   [[ "${COMP_AVAIL[$id]}" != 1 ]];    then box="${C_DIM}[–]${C_RESET}"
        elif [[ "${COMP_REQUIRED[$id]}" == 1 ]]; then box="${C_GREEN}[✔]${C_RESET}"
        elif [[ "${COMP_ENABLED[$id]}" == 1 ]];  then box="${C_GREEN}[x]${C_RESET}"
        else box="[ ]"; fi
        printf ' %s%s %s %-26s %s%s%s\n' "$ptr" "$box" "$(_weight_tag "${COMP_WEIGHT[$id]}")" \
            "${COMP_LABEL[$id]}" "$C_DIM" "${COMP_DESC[$id]}" "$C_RESET"
    done
    printf '\n %sĐã chọn: %s/%s thành phần%s\n' "$C_BOLD" "$(enabled_count)" "${#COMP_IDS[@]}" "$C_RESET"
}

ui_select_components() {
    (( INTERACTIVE )) || return 0
    local cur=0 n=${#COMP_IDS[@]} key id
    printf '\e[?25l'
    while true; do
        _draw_menu "$cur"
        key="$(read_key)"
        id="${COMP_IDS[$cur]}"
        case "$key" in
            UP|k)   cur=$(( (cur - 1 + n) % n )) ;;
            DOWN|j) cur=$(( (cur + 1) % n )) ;;
            SPACE)
                if [[ "${COMP_AVAIL[$id]}" == 1 && "${COMP_REQUIRED[$id]}" != 1 ]]; then
                    COMP_ENABLED[$id]=$(( 1 - COMP_ENABLED[$id] ))
                fi ;;
            a|A) for id in "${COMP_IDS[@]}"; do [[ "${COMP_AVAIL[$id]}" == 1 ]] && COMP_ENABLED[$id]=1; done ;;
            n|N) for id in "${COMP_IDS[@]}"; do [[ "${COMP_REQUIRED[$id]}" == 1 ]] || COMP_ENABLED[$id]=0; done ;;
            ENTER) break ;;
            q|Q|ESC|QUIT) printf '\e[?25h\n'; log_warn "Đã huỷ."; exit 0 ;;
        esac
    done
    printf '\e[?25h\e[H\e[2J'
}

ui_show_plan() {
    local id
    printf '%sKế hoạch cài đặt%s\n' "$C_BOLD" "$C_RESET"
    for id in "${COMP_IDS[@]}"; do
        if [[ "${COMP_ENABLED[$id]}" == 1 ]]; then
            printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "${COMP_LABEL[$id]}"
        else
            printf '  %s– %s%s\n' "$C_DIM" "${COMP_LABEL[$id]}" "$C_RESET"
        fi
    done
    printf '\n'
}

draw_completion_screen() {
    local id st icon col
    printf '\n%s%s════════════════════════════════════════════════════════════════════════%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
    printf '%s%s  HOÀN TẤT — %s v%s%s\n' "$C_BOLD" "$C_GREEN" "$APP_TITLE" "$TARGET_VERSION" "$C_RESET"
    printf '%s%s════════════════════════════════════════════════════════════════════════%s\n\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"

    for id in "${COMP_IDS[@]}"; do
        st="${COMP_STATUS[$id]:-skipped}"
        case "$st" in
            ok)     icon="✔"; col="$C_GREEN" ;;
            failed) icon="✘"; col="$C_RED" ;;
            *)      icon="–"; col="$C_DIM" ;;
        esac
        printf '  %s%s%s %s\n' "$col" "$icon" "$C_RESET" "${COMP_LABEL[$id]}"
    done

    if (( ${#FAILED_PKGS[@]} )); then
        printf '\n%s%sGói cài thất bại (%d):%s %s\n' "$C_BOLD" "$C_YELLOW" "${#FAILED_PKGS[@]}" "$C_RESET" "${FAILED_PKGS[*]}"
        printf '%s  → Cài lại thủ công, ví dụ: yay -S <tên gói>%s\n' "$C_DIM" "$C_RESET"
    fi
    if [[ -n "$BACKUP_DIR" ]]; then
        printf '\n%sSao lưu cấu hình cũ:%s %s\n  Khôi phục: %s./install/install.sh --restore%s\n' "$C_BOLD" "$C_RESET" "$BACKUP_DIR" "$C_CYAN" "$C_RESET"
    fi
    [[ -n "$LOG_FILE" ]] && printf '%sNhật ký:%s %s\n' "$C_BOLD" "$C_RESET" "$LOG_FILE"

    if (( ${#HINTS[@]} )); then
        printf '\n%sGhi chú:%s\n' "$C_BOLD" "$C_RESET"
        printf '  • %s\n' "${HINTS[@]}"
    fi
    local sess=""
    [[ "${COMP_ENABLED[hyprland]:-0}" == 1 ]] && sess="Hyprland"
    [[ "${COMP_ENABLED[niri]:-0}" == 1 ]] && sess="${sess:+$sess hoặc }niri"
    if [[ -n "$sess" ]]; then
        printf '\n%sĐăng xuất/khởi động lại rồi chọn phiên %s.%s\n\n' "$C_DIM" "$sess" "$C_RESET"
    fi
    return 0
}

ui_ask_reboot() {
    (( DRY_RUN )) && return 0
    if (( INTERACTIVE )) && confirm "Khởi động lại ngay bây giờ?" n; then
        log_info "Đang khởi động lại…"
        sudo reboot
    fi
}
