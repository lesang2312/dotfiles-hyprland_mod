#!/usr/bin/env bash

# fresh   = chưa cài | current = đã cài bằng bộ cài này
# legacy  = còn dấu vết của setup.sh đời cũ (chưa có file version)
detect_install_state() {
    local NEW_MARKER="$VERSION_FILE"
    local LEGACY_QS="$HOME/.config/quickshell/cartoon-shell"

    if [[ -f "$NEW_MARKER" ]]; then
        echo "current"
    elif [[ -d "$LEGACY_QS" ]] || compgen -G "$HOME/.dotfiles_backup_*" >/dev/null; then
        echo "legacy"
    else
        echo "fresh"
    fi
}
