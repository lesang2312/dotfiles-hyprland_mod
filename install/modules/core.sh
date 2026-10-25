# shellcheck shell=bash
# =============================================================================
#  core.sh — log, chạy lệnh (hỗ trợ --dry-run), bắt lỗi, dọn dẹp, sudo keep-alive
# =============================================================================

DRY_RUN=0
ASSUME_YES=0
INTERACTIVE=0
LOG_FILE=""
SUDO_PID=""
LOCK_FD=""
MAIN_PID=$$

# ---- màu sắc ---------------------------------------------------------------
core_init_colors() {
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
        C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
        C_BLUE=$'\e[34m'; C_MAGENTA=$'\e[35m'; C_CYAN=$'\e[36m'
    else
        C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''
        C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''
    fi
}
core_init_colors

have() { command -v "$1" &>/dev/null; }

# ---- log -------------------------------------------------------------------
log_init() {
    (( DRY_RUN )) && return 0
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    : >"$LOG_FILE"
    ln -sf "$LOG_FILE" "$LOG_DIR/latest.log"
    # giữ tối đa 10 file log gần nhất
    # shellcheck disable=SC2012
    ls -1t "$LOG_DIR"/install-*.log 2>/dev/null | tail -n +11 | xargs -r rm -f --
}

_log_file() {
    if [[ -n "$LOG_FILE" ]]; then
        printf '[%s] %s\n' "$(date +%T)" "$*" >>"$LOG_FILE"
    fi
    return 0
}

log_info()  { printf '%s[ INFO ]%s %s\n' "$C_CYAN"   "$C_RESET" "$*"; _log_file "INFO  $*"; }
log_ok()    { printf '%s[  OK  ]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; _log_file "OK    $*"; }
log_warn()  { printf '%s[ WARN ]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; _log_file "WARN  $*"; }
log_error() { printf '%s[ LỖI  ]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; _log_file "ERROR $*"; }
die()       { log_error "$*"; trap - ERR; exit 1; }

# ---- chạy lệnh -------------------------------------------------------------
# run <lệnh...>   : in ra thay vì chạy khi --dry-run
run() {
    _log_file "RUN   $*"
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s ' "$C_DIM" "$C_RESET"
        printf '%q ' "$@"; printf '\n'
        return 0
    fi
    local rc=0
    "$@" || rc=$?
    (( rc == 0 )) || _log_file "EXIT  $rc  <- $*"
    return "$rc"
}

# run_quiet: như run nhưng ẩn output (vẫn trả về mã lỗi)
run_quiet() {
    _log_file "RUNQ  $*"
    (( DRY_RUN )) && { printf '%s[dry-run]%s ' "$C_DIM" "$C_RESET"; printf '%q ' "$@"; printf '\n'; return 0; }
    "$@" &>/dev/null
}

# write_file <đường dẫn>  (nội dung đọc từ stdin)
write_file() {
    local dest="$1"
    _log_file "WRITE $dest"
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s ghi file %s\n' "$C_DIM" "$C_RESET" "$dest"
        cat >/dev/null
        return 0
    fi
    mkdir -p "$(dirname "$dest")" || return 1
    cat >"$dest"
}

# ---- bước / tiến trình -----------------------------------------------------
STEP_NO=0
STEP_TOTAL=0

step_begin() {
    STEP_NO=$((STEP_NO + 1))
    printf '\n%s%s[%d/%d]%s %s%s%s\n' "$C_BOLD" "$C_MAGENTA" "$STEP_NO" "$STEP_TOTAL" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
    printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RESET"
    _log_file "STEP  [$STEP_NO/$STEP_TOTAL] $1"
}

# ---- bắt lỗi & dọn dẹp -----------------------------------------------------
on_error() {
    local rc=$? line="${BASH_LINENO[0]:-?}" src="${BASH_SOURCE[1]:-?}" cmd="$BASH_COMMAND"
    trap - ERR
    printf '\n%s%s✘ Cài đặt dừng do lỗi (mã %s)%s\n' "$C_BOLD" "$C_RED" "$rc" "$C_RESET" >&2
    printf '  Vị trí : %s:%s\n  Lệnh   : %s\n' "${src#"$PROJECT_ROOT"/}" "$line" "$cmd" >&2
    [[ -n "$LOG_FILE" ]] && printf '  Log    : %s\n' "$LOG_FILE" >&2
    printf '  Có thể chạy lại installer — các bước đã xong sẽ được bỏ qua (--needed).\n' >&2
    _log_file "FATAL rc=$rc at $src:$line cmd=$cmd"
}

on_exit() {
    local rc=$?
    if [[ -n "$SUDO_PID" ]]; then
        pkill -P "$SUDO_PID" 2>/dev/null || true     # dọn cả `sleep` con
        kill "$SUDO_PID" 2>/dev/null || true
    fi
    printf '\e[?25h' 2>/dev/null || true
    stty echo icanon 2>/dev/null || true
    if [[ -n "$LOCK_FD" ]]; then
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
    return "$rc"
}

on_interrupt() {
    printf '\n%s[ WARN ]%s Đã huỷ bởi người dùng.\n' "$C_YELLOW" "$C_RESET" >&2
    exit 130
}

core_install_traps() {
    set -Eeuo pipefail
    trap on_error ERR
    trap on_exit EXIT
    trap on_interrupt INT TERM
}

# ---- khoá chống chạy song song --------------------------------------------
acquire_lock() {
    (( DRY_RUN )) && return 0
    mkdir -p "$STATE_DIR"
    exec {LOCK_FD}>"$LOCK_FILE"
    if ! flock -n "$LOCK_FD"; then
        LOCK_FD=""
        die "Một tiến trình cài đặt khác đang chạy ($LOCK_FILE)."
    fi
}

# ---- sudo ------------------------------------------------------------------
sudo_keepalive_start() {
    (( DRY_RUN )) && return 0
    have sudo || die "Cần cài 'sudo' trước khi chạy installer."
    log_info "Cần quyền sudo — nhập mật khẩu nếu được hỏi."
    sudo -v || die "Không lấy được quyền sudo."
    (
        while kill -0 "$MAIN_PID" 2>/dev/null; do
            sudo -n true 2>/dev/null || exit 0
            sleep 50
        done
    ) >/dev/null 2>&1 &
    SUDO_PID=$!
}

# ---- tiện ích --------------------------------------------------------------
# list_file_items <file>: in từng mục (bỏ ghi chú, dòng trống)
list_file_items() {
    [[ -f "$1" ]] || return 0
    sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | awk 'NF'
}

dir_has_files() {
    [[ -d "$1" ]] && [[ -n "$(find "$1" -mindepth 1 ! -name '.gitkeep' -print -quit 2>/dev/null)" ]]
}
