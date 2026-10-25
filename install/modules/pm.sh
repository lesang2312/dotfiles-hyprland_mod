#!/usr/bin/env bash

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"

detect_package_manager() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    fi
}

PM_NAME="$(detect_package_manager)"
PM_NAME="${PM_NAME:-pacman}"

source "$PM_MODULES_DIR/$PM_NAME.sh"
