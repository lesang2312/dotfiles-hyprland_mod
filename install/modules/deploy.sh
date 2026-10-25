#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — thư mục người dùng, cài cartoon-shell (BẮT BUỘC),
#              dotfiles & hình nền (tuỳ chọn) — tất cả lấy ONLINE
# =============================================================================

DOTFILES_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$APP_NAME/dotfiles"
WALLPAPERS_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$APP_NAME/wallpapers"

comp_userdirs() {
    local d
    for d in "${USER_DIRS[@]}"; do run mkdir -p "$HOME/$d" || return 1; done
    have xdg-user-dirs-update && { run xdg-user-dirs-update || true; }
    log_ok "Đã tạo thư mục người dùng."
}

pictures_dir() {
    local d=""
    have xdg-user-dir && d="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    [[ -z "$d" || "$d" == "$HOME" ]] && d="$HOME/Pictures"
    printf '%s' "${d%/}"
}

# git_sync <url> <thư mục> — clone nông, lần sau thì cập nhật; thử lại 3 lần
git_sync() {
    local url="$1" dir="$2" i
    have git || { log_error "Thiếu git."; return 1; }
    for i in 1 2 3; do
        if [[ -d "$dir/.git" ]] && run git -C "$dir" fetch --depth 1 origin \
            && { run git -C "$dir" reset --hard FETCH_HEAD; }; then
            return 0
        fi
        run rm -rf "$dir" || return 1
        run mkdir -p "$(dirname "$dir")" || return 1
        run git clone --depth 1 "$url" "$dir" && return 0
        log_warn "Tải lần $i/3 thất bại: $url"
        (( DRY_RUN )) || sleep 2
    done
    return 1
}

# ---- Dotfiles (online, tuỳ chọn) -------------------------------------------
# Gọi TRƯỚC bước sao lưu để biết chính xác mục nào sẽ bị ghi đè.
dotfiles_prepare() {
    [[ "${COMP_ENABLED[dotfiles]:-0}" == 1 ]] || return 0
    log_info "Tải dotfiles: $DOTFILES_REPO_URL"
    if ! git_sync "$DOTFILES_REPO_URL" "$DOTFILES_CACHE"; then
        log_warn "Không tải được dotfiles — bỏ qua thành phần này."
        COMP_ENABLED[dotfiles]=0
    fi
}

# Thư mục cấu hình riêng của từng compositor: chỉ chép khi compositor đó được chọn
declare -A COMPOSITOR_CONF_DIRS=( [hypr]=hyprland [niri]=niri )

dotfiles_top_entries() {
    local src="$DOTFILES_CACHE/$DOTFILES_SUBDIR" name comp
    [[ -d "$src" ]] || return 0
    while IFS= read -r name; do
        comp="${COMPOSITOR_CONF_DIRS[$name]:-}"
        if [[ -n "$comp" && "${COMP_ENABLED[$comp]:-0}" != 1 ]]; then
            continue
        fi
        printf '%s\n' "$name"
    done < <(find "$src" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitkeep' -printf '%f\n')
}

comp_dotfiles() {
    local src="$DOTFILES_CACHE/$DOTFILES_SUBDIR" name
    if ! (( DRY_RUN )) && [[ ! -d "$src" ]]; then
        log_error "Repo dotfiles không có thư mục '$DOTFILES_SUBDIR'."; return 1
    fi
    run mkdir -p "$HOME/.config" || return 1
    while IFS= read -r name; do
        run cp -r --preserve=mode "$src/$name" "$HOME/.config/" || return 1
        manifest_add "$HOME/.config/$name"
        log_ok "  $name"
    done < <(dotfiles_top_entries)
}

# ---- Hình nền (online, tuỳ chọn) -------------------------------------------
comp_wallpapers() {
    local dest src repo="$WALLPAPERS_CACHE"
    dest="$(pictures_dir)/Wallpapers"
    # cùng repo với dotfiles → dùng lại bản đã tải, khỏi tải hai lần
    if [[ "$WALLPAPERS_REPO_URL" == "$DOTFILES_REPO_URL" && -d "$DOTFILES_CACHE/.git" ]]; then
        repo="$DOTFILES_CACHE"
    else
        git_sync "$WALLPAPERS_REPO_URL" "$WALLPAPERS_CACHE" || { log_error "Không tải được hình nền."; return 1; }
    fi
    src="$repo"
    if   [[ -d "$repo/$WALLPAPERS_SUBDIR" ]]; then src="$repo/$WALLPAPERS_SUBDIR"
    elif [[ -d "$repo/images" ]];             then src="$repo/images"; fi
    run mkdir -p "$dest" || return 1
    log_info "Chép hình nền → $dest"
    if (( DRY_RUN )); then
        run cp -r "$src"/. "$dest"/; return 0
    fi
    ( cd "$src" && find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) \
        -not -path './.git/*' -exec cp -f --parents -t "$dest" {} + ) || return 1
}

# ---- Cartoon Shell (BẮT BUỘC) ----------------------------------------------
comp_shell() {
    local target="$SHELL_TARGET_DIR" tmp="${SHELL_TARGET_DIR}.new" i ok=0
    have git || { log_error "Thiếu git."; return 1; }

    log_info "Tải $SHELL_REPO_URL"
    run mkdir -p "$(dirname "$target")" || return 1
    # clone sang thư mục tạm; chỉ thay bản cũ khi clone thành công
    for i in 1 2 3; do
        run rm -rf "$tmp" || return 1
        if run git clone --depth 1 "$SHELL_REPO_URL" "$tmp"; then ok=1; break; fi
        log_warn "Clone lần $i/3 thất bại."
        (( DRY_RUN )) || sleep 3
    done
    if (( ! ok )); then
        run rm -rf "$tmp" || true
        log_error "Không clone được cartoon-shell (bản cũ được giữ nguyên)."
        return 1
    fi
    run rm -rf "$target" || return 1
    run mv "$tmp" "$target" || return 1
    manifest_add "$target"
    log_ok "Đã cài cartoon-shell → $target"
}
