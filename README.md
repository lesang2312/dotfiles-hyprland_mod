# Hyprland (Lua) Dotfiles

A complete Hyprland(Lua) configuration with Quickshell, custom themes, and essential tools for a beautiful Wayland desktop experience.

> [!NOTE]
> This is an updated and feature-extended version of the original "dotfiles-hyprland" project created and owned by **Mai Duong Long** (mailong2401).

## 🚀 New Features Added in This Version

Compared to the original repository, this build includes the following pre-configured additions:

* **Custom Kitty Opacity Slider**: Easily adjust the terminal's background transparency on-the-fly using a convenient slider.
* **Vietnamese Input Method**: Pre-configured `fcitx5` for seamless Vietnamese typing.
* **Bluetooth Support**: Native bluetooth modules enabled out-of-the-box.
* **Audio Control**: Fully integrated speaker and volume control modules.
* **Papirus-Dark Icons**: Installed and applied automatically by the installer.
* **One-line `curl` Installer**: Install everything with a single command.
* **Additional System Updates**: Includes performance optimizations, enhanced visual transitions, and key stability fixes for the core modules.

## 💻 Requirements

- **Distro**: Arch Linux (or Arch-based: Manjaro, EndeavourOS, CachyOS, etc.)
- **Wayland** compositor with **Hyprland (Lua)** — installed automatically
- **Internet connection** and at least 4 GB free disk space

The installer automatically sets up the base system utilities (`git`, `base-devel`), Hyprland, Quickshell and all packages listed below.

## 🔧 Installation

> Supported: Arch Linux and Arch-based distros (Manjaro, EndeavourOS, CachyOS, …). Run as a **normal user** — the installer calls `sudo` by itself when needed.

### Method 1 — One-line install with `curl` (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash
```

The installer lives in this repository (`install/`). It downloads the dotfiles (`.config`), wallpapers (`Pictures/Wallpapers`) and the Cartoon Shell config ([cartoon-shell_mod](https://github.com/lesang2312/cartoon-shell_mod)) for you, and opens an interactive menu (↑/↓ move · Space toggle · `a` all · `n` none · Enter start · `q` quit). Useful options:

```bash
# Unattended install, skip the heavy extra fonts
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash -s -- --yes --skip fonts-extra

# Preview only, nothing is changed
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash -s -- --dry-run

# Install only Cartoon Shell (+ required core packages)
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash -s -- --only shell
```

| Option | Description |
|--------|-------------|
| `-y, --yes` | Run unattended with default choices |
| `--dry-run` | Print the commands without changing the system |
| `--only a,b` / `--skip a,b` | Install only / skip the given components, e.g. `--skip dotfiles,wallpapers` (`--list` to see them) |
| `--restore [name]` | Restore a previous backup |
| `--uninstall` | Remove copied files (installed packages are kept) |

### Method 2 — Clone and run `setup.sh`

```bash
cd ~
git clone https://github.com/lesang2312/dotfiles-hyprland_mod
cd dotfiles-hyprland_mod
chmod +x setup.sh
./setup.sh
```

### 🪟 Choosing the compositor (Hyprland / niri / both)

In the menu, tick **Hyprland**, **niri**, or both (Hyprland is ticked by default). The installer then installs only the packages **and copies only the config folders** of what you picked:

| Selection | Packages | Config copied to `~/.config` |
|-----------|----------|------------------------------|
| Hyprland | `hyprland`, `xdg-desktop-portal-hyprland` | `hypr/` + shared configs |
| niri | `niri`, `xwayland-satellite`, `xdg-desktop-portal-gnome/gtk`, `gnome-keyring` | `niri/` + shared configs |
| Both | all of the above | `hypr/`, `niri/` + shared configs |

Shared configs are `fish/`, `kitty/`, `matugen/`, `gtk-3.0/`, `gtk-4.0/`, `starship.toml`, `xdg-desktop-portal/`. Existing files are backed up first.

```bash
# Unattended: niri only
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash -s -- --yes --only niri,dotfiles,wallpapers,aur,icons,userdirs,audio,bluetooth,input,fonts

# Unattended: both
curl -fsSL https://raw.githubusercontent.com/lesang2312/dotfiles-hyprland_mod/main/install/get.sh | bash -s -- --yes --skip fonts-extra --only hyprland,niri
```

> Already have your own setup? Add `--skip dotfiles` to leave `~/.config` untouched. Use `--list` to see all component ids.

### 🎨 Icon theme: Papirus-Dark

Both methods install `papirus-icon-theme` and set **Papirus-Dark** as the default icon theme automatically (component `icons`; skip it with `--skip icons`). To apply it manually:

```bash
sudo pacman -S --needed papirus-icon-theme
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
```

### 🔐 Login screen: SDDM (automatic)

The installer sets up **SDDM** with the **cartoon** theme by default — no selection needed (component `sddm`; skip it with `--skip sddm`). It runs right after Cartoon Shell is cloned and:

1. installs `sddm`, `qt6-declarative`, `qt6-svg`;
2. copies the theme from the Cartoon Shell repo (`sddm/themes/cartoon`) to `/usr/share/sddm/themes/cartoon`;
3. sets it as the default theme (`/etc/sddm.conf.d/10-cartoon-shell.conf`; `Current=` in `/etc/sddm.conf` is updated too if present);
4. enables `sddm.service` (replacing any other display manager; takes effect after the next reboot);
5. seeds the login background with your first wallpaper — afterwards Cartoon Shell keeps it in sync with your current wallpaper (turn off with `wallpaper.syncSddm = false` in the shell `settings.json`).

The theme itself (welcome splash + login card) lives in the **Cartoon Shell** repository, not in this one. Customize colors/language in `theme.conf.user` inside the theme folder. `--uninstall` removes the theme and config (the `sddm` package is kept).

The installer will:
1. Check your system (distro, sudo, internet, disk space)
2. Back up your existing config (if any)
3. Update your system and install all required packages
4. Set up the `yay` AUR helper (if not installed) and install AUR packages
5. Install and apply the Papirus-Dark icon theme
6. Configure audio, Bluetooth and the Vietnamese input method
7. Clone the Cartoon Shell (Quickshell) configuration
8. Install the SDDM login screen with the cartoon theme
9. Ask if you want to reboot

## Installed Packages

### Core Packages (pacman)

| Package | Description |
|---------|-------------|
| `base-devel` | Essential tools for building and compiling packages |
| `hyprland` | Dynamic tiling Wayland compositor |
| `kitty` | GPU-accelerated terminal emulator |
| `brightnessctl` | Brightness control tool |
| `wl-clipboard` | Wayland clipboard utilities |
| `noto-fonts-cjk` | Google Noto CJK fonts support |
| `nautilus` | GNOME file manager (replaces Thunar) |
| `grim` | Screenshot tool for Wayland |
| `slurp` | Screen area selection tool |
| `xdg-desktop-portal-hyprland` | XDG Desktop Portal backend for Hyprland |
| `jq` | Command-line JSON processor |
| `matugen` | Material You color palette generator |
| `starship` | Customizable cross-shell prompt |
| `fish` | User-friendly command-line shell |
| `adw-gtk-theme` | Adwaita GTK theme for modern application styling |
| `bc` | Arbitrary precision calculator language |
| `ttf-nerd-fonts-symbols` | High-quality icon and symbol fonts |
| `qt6-multimedia` | Qt6 Multimedia API support for Quickshell plugins |
| `pipewire` | Low-latency audio and video server |
| `pipewire-pulse` | PulseAudio replacement layer for PipeWire |
| `pipewire-alsa` | ALSA support for PipeWire |
| `pipewire-jack` | JACK audio server compatibility layer |
| `wireplumber` | Modular session and policy manager for PipeWire |
| `pavucontrol` | PulseAudio volume control GUI |
| `bluez` | Linux Bluetooth protocol stack |
| `bluez-utils` | Development and debugging utilities for Bluetooth |
| `blueman` | Full-featured Bluetooth manager GUI |
| `fcitx5` | Next-generation input method framework |
| `fcitx5-gtk` | GTK IM module for Fcitx5 |
| `fcitx5-qt` | Qt IM module for Fcitx5 |
| `fcitx5-configtool` | Graphical configuration tool for Fcitx5 |
| `fcitx5-unikey` | Vietnamese Unikey input method engine for Fcitx5 |
| `papirus-icon-theme` | Pixel-perfect icon theme (**Papirus-Dark** is set as default) |
| `sddm`, `qt6-declarative`, `qt6-svg` | Login manager and Qt 6 modules used by the **cartoon** SDDM theme |
| `glib2`, `dconf`, `gsettings-desktop-schemas` | `gsettings` support used to apply the icon theme |

### AUR Packages (yay)

| Package | Description |
|---------|-------------|
| `quickshell-git` | Modern shell interface framework based on Qt/QML |
| `sysstat` | System performance monitoring tools (used for bar widgets) |
| `otf-comicshanns-nerd` | Comic Shanns font patched with Nerd Font icons |
| `cava` | Console-based Audio Visualizer |
| `ttf-material-symbols-variable-git` | Google's Material Symbols font for modern UI icons |
| `qt6-5compat` | Qt 6 module containing compatibility APIs with Qt 5 |


### Additional Configuration

| Component | Source |
|-----------|--------|
| Quickshell Theme | [cartoon-shell](https://github.com/lesang2312/cartoon-shell_mod.git) |

## Backup

Your old configuration is automatically backed up to:
```
~/.dotfiles_backup_YYYYMMDD_HHMMSS/
```

## ⌨️ Keybindings Customization

You can easily modify, add, or change all system shortcuts, workspace management hotkeys, and window control rules by editing the Lua configuration file.

### Custom Keybindings File Path:
```bash
~/.config/hypr/config/keybindings.lua
```

### How to Change Keybindings:
* **Step 1**: Open your Terminal or your preferred text editor (e.g., VS Code, VSCodium, or Nano).
* **Step 2**: Open the configuration file using the absolute path:
  ```bash
  nano ~/.config/hypr/config/keybindings.lua
  ```
* **Step 3**: Locate the shortcuts you want to change (e.g., window navigation, application launchers, or system volume toggles).
* **Step 4**: Modify the key values according to the Hyprland Lua configuration syntax.
* **Step 5**: Save the file. The hotkey changes will automatically apply without needing to reboot your computer.

## Credits

- Hyprland: [https://hyprland.org](https://hyprland.org)
- Quickshell: [https://quickshell.outfoxxed.me](https://quickshell.outfoxxed.me)
- Cartoon Shell: [https://github.com/lesang2312/cartoon-shell](https://github.com/lesang2312/cartoon-shell_mod)

## License

MIT License - Feel free to use and modify

## Support

For issues or questions, please open an issue on GitHub.

---

Made with ❤️ for the Hyprland community