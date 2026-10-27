#!/usr/bin/env bash
# Chụp màn hình / quay màn hình — dùng chung cho niri và Hyprland.
# Dùng:  screenshot.sh area | full | record
# Thư mục lưu: $SCREENSHOT_DIR, ảnh mặc định ~/Pictures/Screenshots, video ~/Videos/Recordings (luôn tính từ $HOME, không hardcode tên user).

DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
REC_DIR="${RECORD_DIR:-$HOME/Videos/Recordings}"
mkdir -p "$DIR" "$REC_DIR" || exit 1
ts="$(date +'%Y-%m-%d_%H-%M-%S')"

notify() { command -v notify-send >/dev/null && notify-send -a Screenshot "$@"; }

copy_image() { command -v wl-copy >/dev/null && wl-copy -t image/png < "$1"; }

case "${1:-area}" in
  area)
    geom="$(slurp)" || exit 0          # Esc / huỷ chọn vùng → thoát im lặng
    [ -n "$geom" ] || exit 0
    file="$DIR/screenshot_$ts.png"
    grim -g "$geom" "$file" || { notify "Chụp màn hình thất bại"; exit 1; }
    copy_image "$file"; notify "Đã lưu ảnh" "$file"
    ;;
  full)
    file="$DIR/screenshot_$ts.png"
    grim "$file" || { notify "Chụp màn hình thất bại"; exit 1; }
    copy_image "$file"; notify "Đã lưu ảnh" "$file"
    ;;
  record)
    if pkill -INT -x wf-recorder; then notify "Đã dừng quay màn hình"; exit 0; fi
    command -v wf-recorder >/dev/null || { notify "Thiếu wf-recorder"; exit 1; }
    geom="$(slurp)" || exit 0
    [ -n "$geom" ] || exit 0
    file="$REC_DIR/recording_$ts.mp4"
    notify "Bắt đầu quay" "$file"
    wf-recorder -r 60 -x yuv444p -p preset=ultrafast -p crf=5 -g "$geom" -f "$file"
    ;;
  *) echo "Usage: ${0##*/} area|full|record" >&2; exit 2 ;;
esac
