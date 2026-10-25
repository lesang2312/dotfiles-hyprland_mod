#!/usr/bin/env bash
# =============================================================================
#  pm/pacman.sh — backend pacman + AUR helper
#  Quy ước: gói lỗi KHÔNG làm dừng installer, được ghi vào FAILED_PKGS.
# =============================================================================

PM_BOOTSTRAP_TOOLS=(git curl jq unzip fontconfig base-devel)

pm_prepare_repos() { pm_enable_multilib; }

pm_bootstrap_install() {
    run sudo pacman -Sy --noconfirm --needed "$@"
}

pm_bootstrap_helper() {
    pm_ensure_aur_helper || true
}

FAILED_PKGS=()
AUR_HELPER=""

pm_is_installed() { have pacman && pacman -Q "$1" &>/dev/null; }
pm_in_repo()      { have pacman && pacman -Si "$1" &>/dev/null; }
pm_group_exists() { have pacman && [[ -n "$(pacman -Sgq "$1" 2>/dev/null)" ]]; }

# In ra các gói CHƯA cài (kể cả khi pacman không tồn tại — dùng cho dry-run)
pm_missing() {
    if have pacman; then
        pacman -T "$@" 2>/dev/null || true
    else
        printf '%s\n' "$@"
    fi
}

pm_enable_multilib() {
    [[ -f /etc/pacman.conf ]] || return 0
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
        log_info "Bật kho multilib…"
        run sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf || return 1
    fi
}

pm_full_upgrade() {
    run sudo pacman -Syu --noconfirm
}

pm_ensure_aur_helper() {
    if have yay;  then AUR_HELPER=yay;  return 0; fi
    if have paru; then AUR_HELPER=paru; return 0; fi

    log_info "Chưa có AUR helper — đang cài yay-bin…"
    run sudo pacman -S --needed --noconfirm base-devel git || return 1
    if (( DRY_RUN )); then
        log_info "(dry-run) bỏ qua build yay-bin"
        AUR_HELPER=yay
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
        rm -rf "$tmp"
        AUR_HELPER=yay
        log_ok "Đã cài yay."
        return 0
    fi
    rm -rf "$tmp"
    log_warn "Không cài được yay — các gói AUR sẽ bị bỏ qua."
    return 1
}

_pm_aur_install() {
    local pkg="$1"
    [[ -n "$AUR_HELPER" ]] || pm_ensure_aur_helper || return 1
    local jobs
    jobs="$(nproc 2>/dev/null || echo 2)"
    (( jobs > 4 )) && jobs=4          # tránh hết RAM khi build
    run env MAKEFLAGS="-j$jobs" CARGO_BUILD_JOBS="$jobs" \
        "$AUR_HELPER" -S --needed --noconfirm --ask=4 "$pkg"
}

# pm_install_many <gói...> — cài hàng loạt, tự chia repo/AUR, lỗi → FAILED_PKGS
pm_install_many() {
    local -a want=("$@") missing=() repo=() aur=()
    local p
    (( ${#want[@]} )) || return 0

    mapfile -t missing < <(pm_missing "${want[@]}")
    if (( ${#missing[@]} == 0 )); then
        log_ok "Tất cả ${#want[@]} gói đã có sẵn."
        return 0
    fi
    log_info "Cần cài ${#missing[@]}/${#want[@]} gói."

    for p in "${missing[@]}"; do
        if (( DRY_RUN )) && ! have pacman; then repo+=("$p")
        elif pm_in_repo "$p"; then repo+=("$p")
        else aur+=("$p"); fi
    done

    if (( ${#repo[@]} )); then
        log_info "Kho chính (${#repo[@]}): ${repo[*]}"
        if ! run sudo pacman -S --needed --noconfirm "${repo[@]}"; then
            log_warn "Cài hàng loạt lỗi — thử lại từng gói để cô lập gói hỏng."
            for p in "${repo[@]}"; do
                run sudo pacman -S --needed --noconfirm "$p" || FAILED_PKGS+=("$p")
            done
        fi
    fi

    if (( ${#aur[@]} )); then
        log_info "AUR (${#aur[@]}): ${aur[*]}"
        for p in "${aur[@]}"; do
            _pm_aur_install "$p" || { log_warn "Lỗi gói AUR: $p"; FAILED_PKGS+=("$p"); }
        done
    fi
    return 0
}

# pm_install_list <file.list>
pm_install_list() {
    local file="$1"
    local -a pkgs=()
    mapfile -t pkgs < <(list_file_items "$file")
    pm_install_many "${pkgs[@]}"
}

pm_remove_conflicting() {
    local pkg="$1"
    pm_is_installed "$pkg" || return 0
    run sudo pacman -Rdd --noconfirm "$pkg" || true
}

pm_missing_pkgs() { pm_missing "$@"; }
pm_remove_pkg()   { run sudo pacman -Rns --noconfirm "$1" >/dev/null 2>&1 || true; }
pm_remove_conflicting_pkg() { pm_remove_conflicting "$1"; }
