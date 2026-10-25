#!/usr/bin/env bash
# Đóng gói bản phát hành: dist/cartoon-shell-installer-<version>.tar.gz + sha256
set -euo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
ver="$(tr -d '[:space:]' <version.txt)"
name="cartoon-shell-installer-$ver"
mkdir -p dist
tar --transform "s,^,$name/," -czf "dist/$name.tar.gz" \
    --exclude='./dist' --exclude='.git' \
    version.txt README.md install
( cd dist && sha256sum "$name.tar.gz" >"$name.tar.gz.sha256" )
echo "✔ dist/$name.tar.gz"
