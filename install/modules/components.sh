# shellcheck shell=bash
# =============================================================================
#  components.sh — đăng ký các thành phần cài đặt (thứ tự = thứ tự chạy)
#  Thêm thành phần mới: viết hàm comp_<tên> rồi thêm 1 dòng register_component.
# =============================================================================

COMP_IDS=()
declare -A COMP_LABEL COMP_DESC COMP_FUNC COMP_ENABLED COMP_REQUIRED COMP_AVAIL COMP_WEIGHT COMP_STATUS

# register_component <id> <hàm> <nhãn> <mô tả> <mặc định 0/1> <bắt buộc 0/1> <nhẹ|vừa|nặng>
register_component() {
    local id="$1"
    COMP_IDS+=("$id")
    COMP_FUNC[$id]="$2"; COMP_LABEL[$id]="$3"; COMP_DESC[$id]="$4"
    COMP_ENABLED[$id]="$5"; COMP_REQUIRED[$id]="$6"; COMP_WEIGHT[$id]="$7"
    COMP_AVAIL[$id]=1; COMP_STATUS[$id]=""
}

register_all_components() {
    register_component upgrade       comp_upgrade       "Cập nhật hệ thống"       "pacman -Syu, bật kho multilib"                    1 0 vừa
    register_component core          comp_core          "Gói cốt lõi"             "kitty, nautilus, matugen, fish, starship…"        1 1 vừa
    register_component hyprland      comp_hyprland      "Hyprland"                "cài hyprland + chép .config/hypr"         1 0 vừa
    register_component niri          comp_niri          "niri"                    "cài niri + portal + chép .config/niri"    0 0 vừa
    register_component aur           comp_aur           "Gói AUR"                 "yay, quickshell-git, cava, fonts icon…"           1 0 vừa
    register_component icons         comp_icons         "Icon theme Papirus-Dark" "papirus-icon-theme + đặt Papirus-Dark mặc định"   1 0 nhẹ
    register_component userdirs      comp_userdirs      "Thư mục người dùng"      "Music, Documents, Pictures… + xdg-user-dirs"      1 0 nhẹ
    register_component audio         comp_audio         "Âm thanh"                "PipeWire + WirePlumber, bỏ tắt tiếng, 80%"        1 0 nhẹ
    register_component bluetooth     comp_bluetooth     "Bluetooth"               "bluez + blueman, tự bật khi khởi động"            1 0 nhẹ
    register_component input         comp_input         "Bộ gõ tiếng Việt"        "fcitx5 + Unikey, biến môi trường, autostart"      1 0 nhẹ
    register_component fonts         comp_fonts         "Font cơ bản"             "Noto, Liberation, JetBrains Mono, Roboto…"        1 0 vừa
    register_component fonts_nerd    comp_fonts_nerd    "Nerd Fonts đầy đủ"       "Nhóm gói nerd-fonts (dung lượng lớn)"             1 0 nặng
    register_component fonts_bigblue comp_fonts_bigblue "BigBlue Terminal Nerd Font" "Tải online → /usr/share/fonts (cho đồng hồ)"  1 0 nhẹ
    register_component fonts_extra   comp_fonts_extra   "Font mở rộng (AUR)"      "google-fonts, ms-fonts, Playfair, Oswald…"        1 0 nặng
    register_component dotfiles      comp_dotfiles      "Dotfiles (online)"       "dotfiles-hyprland_mod/.config → ~/.config"             1 0 nhẹ
    register_component wallpapers    comp_wallpapers    "Hình nền (online)"       "Pictures/Wallpapers → ~/Pictures/Wallpapers"          1 0 vừa
    register_component shell         comp_shell         "Quickshell cartoon-shell" "git clone vào ~/.config/quickshell"   1 1 nhẹ

    # Nguồn online tuỳ chọn: chưa khai báo URL thì khoá thành phần
    [[ -n "$DOTFILES_REPO_URL" ]]    || _comp_unavailable dotfiles
    [[ -n "$WALLPAPERS_REPO_URL" ]]  || _comp_unavailable wallpapers
}

_comp_unavailable() { COMP_AVAIL[$1]=0; COMP_ENABLED[$1]=0; }

comp_exists() { [[ -n "${COMP_FUNC[$1]:-}" ]]; }

# Áp dụng --only / --skip (danh sách id phân tách bằng dấu phẩy, '-' hoặc '_' đều được)
apply_selection_flags() {
    local only="$1" skip="$2" id x
    _norm() { printf '%s' "${1//-/_}"; }
    if [[ -n "$only" ]]; then
        for id in "${COMP_IDS[@]}"; do
            [[ "${COMP_REQUIRED[$id]}" == 1 ]] || COMP_ENABLED[$id]=0
        done
        IFS=',' read -ra arr <<<"$only"
        for x in "${arr[@]}"; do
            x="$(_norm "$x")"
            comp_exists "$x" || die "Thành phần không tồn tại: $x (xem --list)"
            [[ "${COMP_AVAIL[$x]}" == 1 ]] && COMP_ENABLED[$x]=1
        done
    fi
    if [[ -n "$skip" ]]; then
        IFS=',' read -ra arr <<<"$skip"
        for x in "${arr[@]}"; do
            x="$(_norm "$x")"
            comp_exists "$x" || die "Thành phần không tồn tại: $x (xem --list)"
            [[ "${COMP_REQUIRED[$x]}" == 1 ]] && { log_warn "'$x' là bắt buộc, không thể bỏ qua."; continue; }
            COMP_ENABLED[$x]=0
        done
    fi
}

enabled_count() {
    local n=0 id
    for id in "${COMP_IDS[@]}"; do [[ "${COMP_ENABLED[$id]}" == 1 ]] && n=$((n+1)); done
    echo "$n"
}

enabled_list() {
    local out=() id
    for id in "${COMP_IDS[@]}"; do [[ "${COMP_ENABLED[$id]}" == 1 ]] && out+=("$id"); done
    echo "${out[*]}"
}

print_component_list() {
    local id mark
    printf '%-14s %-6s %s\n' "ID" "NẶNG" "MÔ TẢ"
    for id in "${COMP_IDS[@]}"; do
        mark=""; [[ "${COMP_REQUIRED[$id]}" == 1 ]] && mark=" (bắt buộc)"
        [[ "${COMP_AVAIL[$id]}" == 1 ]] || mark=" (chưa khai báo nguồn online)"
        printf '%-14s %-6s %s — %s%s\n' "${id//_/-}" "${COMP_WEIGHT[$id]}" "${COMP_LABEL[$id]}" "${COMP_DESC[$id]}" "$mark"
    done
}
