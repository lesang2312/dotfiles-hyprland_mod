#!/usr/bin/env bash
# Cài nhanh:  curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash
# Tuỳ chọn :  ... | bash -s -- --yes --skip fonts-extra
set -e

main() {
    local slug="${REPO_SLUG:-lesang2312/dotfiles-hyprland_mod}"   # <-- repo chứa bộ cài này
    local branch="${CARTOON_BRANCH:-main}"
    local dir
    if [[ "$slug" == YOUR_GITHUB_USER/* ]]; then
        echo "Chưa cấu hình repo: sửa 'slug' trong get.sh hoặc đặt REPO_SLUG=user/repo" >&2
        exit 1
    fi
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    curl -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install.sh"
    export REPO_SLUG="$slug"
    # curl | bash chiếm stdin → nối lại với terminal để menu hoạt động
    if [ -t 0 ]; then
        bash "$dir/install.sh" "$@"
    elif [ -r /dev/tty ]; then
        bash "$dir/install.sh" "$@" < /dev/tty
    else
        bash "$dir/install.sh" --yes "$@"
    fi
}

main "$@"
