#!/usr/bin/env bash
# =============================================================================
#  version.sh — đường dẫn trạng thái, phiên bản và manifest file đã chép
# =============================================================================

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_NAME"
VERSION_FILE="$STATE_DIR/version"
MANIFEST_FILE="$STATE_DIR/deployed.list"
LOG_DIR="$STATE_DIR/logs"
BACKUP_ROOT="$STATE_DIR/backups"
LOCK_FILE="$STATE_DIR/install.lock"
DEFAULT_FALLBACK_VERSION="1.0.0"

get_installed_version() {
    [[ -f "$VERSION_FILE" ]] || return 0
    awk -F= '/^APP_VERSION=/{gsub(/"/, "", $2); print $2; exit}' "$VERSION_FILE"
}

get_target_version() {
    local root="$1" ver=""
    [[ -f "$root/version.txt" ]] && ver="$(tr -d '[:space:]' <"$root/version.txt")"
    echo "${ver:-$DEFAULT_FALLBACK_VERSION}"
}

get_target_commit() {
    local root="$1" c=""
    if [[ -d "$root/.git" ]] && have git; then
        c="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)"
    fi
    echo "${c:-local}"
}

write_version_state() {   # write_version_state <version> <commit> "<thành phần>"
    (( DRY_RUN )) && return 0
    mkdir -p "$STATE_DIR"
    local tmp="${VERSION_FILE}.tmp.$$"
    cat >"$tmp" <<STATE
APP_VERSION="$1"
APP_COMMIT="$2"
INSTALLED_AT="$(date -Is)"
COMPONENTS="$3"
LAST_BACKUP="${BACKUP_DIR:-}"
STATE
    mv -f "$tmp" "$VERSION_FILE"
}

# Ghi lại đường dẫn đã chép để --uninstall biết đường dọn
manifest_add() {
    (( DRY_RUN )) && return 0
    mkdir -p "$STATE_DIR"
    touch "$MANIFEST_FILE"
    grep -qxF -- "$1" "$MANIFEST_FILE" || printf '%s\n' "$1" >>"$MANIFEST_FILE"
}
