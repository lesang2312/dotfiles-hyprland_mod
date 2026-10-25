# Bộ cài đặt (dotfiles-hyprland_mod + cartoon-shell_mod)

Bộ cài dạng module cho Arch Linux + Hyprland + Quickshell (`cartoon-shell`), tổ chức giống bộ cài serpantinum.

```
dotfiles-hyprland_mod/
├── .config/  Pictures/Wallpapers/   (dotfiles & hình nền, do bộ cài tải về)
├── install/
│   ├── install.sh          Điểm vào: đọc tham số, điều phối các bước
│   ├── get.sh              Cài nhanh bằng `curl | bash`
│   ├── app.conf            Tên, repo shell, đường dẫn, URL font — chỗ duy nhất cần sửa khi đổi dự án
│   └── modules/
│       ├── core.sh         Log, run (dry-run), bắt lỗi, khoá, sudo keep-alive
│       ├── pm.sh           Nhận diện package manager
│       ├── pm/pacman.sh    Backend pacman + AUR (cài hàng loạt, cô lập gói lỗi)
│       ├── deps.sh         Kiểm tra hệ thống, DANH SÁCH GÓI, cài gói & font (kể cả BigBlue online)
│       ├── state.sh        Nhận diện fresh / current / legacy
│       ├── migrate.sh      Sao lưu, khôi phục, di trú từ setup.sh cũ
│       ├── deploy.sh       Thư mục người dùng, chép config/hình nền/font, clone cartoon-shell
│       ├── version.sh      Phiên bản, file trạng thái, manifest file đã chép
│       ├── config.sh       Bộ gõ fcitx5 + Unikey, icon theme Papirus-Dark
│       ├── service.sh      PipeWire, Bluetooth
│       ├── ui.sh           Banner, menu chọn thành phần, màn hình tổng kết
│       ├── components.sh   Đăng ký thành phần & --only/--skip
│       └── uninstall.sh    Gỡ cài đặt
├── tools/release.sh        Đóng gói dist/*.tar.gz + sha256
├── setup.sh                Cách cài cũ (không dùng bộ cài này)
└── version.txt
```

## Cài đặt

```bash
./install/install.sh                 # menu tương tác
./install/install.sh -y --skip fonts-extra
./install/install.sh --dry-run       # xem trước, không đổi gì
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash
```

Menu: ↑/↓ di chuyển · Space bật/tắt · a chọn hết · n bỏ hết · Enter bắt đầu · q thoát.
Repo mặc định là `lesang2312/dotfiles-hyprland_mod` (`RAW_SLUG` trong install.sh, `slug` trong get.sh); đổi bằng biến `REPO_SLUG=user/repo`.

| Tuỳ chọn | Tác dụng |
|---|---|
| `-y, --yes` | Chạy tự động |
| `--dry-run` | In lệnh, không thay đổi hệ thống |
| `--only a,b` / `--skip a,b` | Chọn / bỏ thành phần (`--list` để xem) |
| `--restore [tên]` | Khôi phục cấu hình từ bản sao lưu |
| `--uninstall` | Gỡ file đã chép, khôi phục cấu hình gốc (giữ nguyên gói) |

**Mọi thứ đều lấy online** — bộ cài không đóng kèm cấu hình/ảnh/font: gói qua pacman/AUR, BigBlue Terminal Nerd Font từ GitHub, `cartoon-shell_mod` bằng `git clone`.
- `cartoon-shell` là thành phần **bắt buộc** (không tắt được; clone lỗi sau 3 lần thì dừng cài).
- Trả lời `n` ở câu "Bắt đầu cài đặt?" sẽ **quay lại menu chọn**; thoát hẳn bằng `q`.
- Dotfiles (`.config`) và hình nền (`Pictures/Wallpapers`) lấy từ chính repo `dotfiles-hyprland_mod`; shell lấy từ `cartoon-shell_mod`. Đổi bằng `DOTFILES_REPO_URL`, `WALLPAPERS_REPO_URL`, `SHELL_REPO_URL` hoặc bỏ qua bằng `--skip dotfiles,wallpapers`.
- Chọn compositor: menu có `hyprland` và `niri`; chỉ chép `.config/hypr` khi chọn hyprland, `.config/niri` khi chọn niri, các thư mục còn lại (fish, kitty, matugen, gtk-*, starship.toml, xdg-desktop-portal) luôn chép. Chi tiết: `hyprland` (mặc định bật) và `niri` (mặc định tắt). Chỉ dùng niri: `--only niri,aur,icons --skip dotfiles`. `--skip dotfiles` giữ nguyên cấu hình sẵn có của bạn.
- Chỉ cài shell: `--only shell` (kèm gói cốt lõi bắt buộc).
- Thành phần `icons` cài `papirus-icon-theme` và chạy `gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"` (bỏ qua bằng `--skip icons`; đổi theme bằng biến `ICON_THEME_NAME`).
Trạng thái, log, backup ở `~/.local/state/cartoon-shell/`.

## Thêm thành phần

Viết hàm `comp_xyz` (nhớ `|| return 1` cho lệnh quan trọng) trong module phù hợp, rồi thêm một dòng `register_component` trong `components.sh`.
