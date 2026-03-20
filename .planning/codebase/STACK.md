# Technology Stack

**Analysis Date:** 2026-03-20

## Languages

**Primary:**
- Nix - NixOS configuration language for system and user configuration
- Lua - Used in Neovim configuration (`/config/nvim/lua/**/*`)
- Python - Used in Qtile window manager configuration and development
- Bash - Shell scripting for utilities and aliases (`/config/bash_*.sh`)
- JavaScript/TypeScript - Development tooling and Node-based formatters

**Secondary:**
- SQL - Database querying via pgcli and sqls language server
- TOML - Configuration files (evremap mapping)
- YAML - Secrets management (sops-nix)
- JSON - Configuration for various tools

## Runtime

**Environment:**
- NixOS 25.05 - Linux-based operating system and package manager
- x86_64-linux (x86-64 architecture)

**Package Manager:**
- Nix Flakes - Modern Nix package management with lock files
- Lockfile: `flake.lock` (present, 371 lines)

## Frameworks

**Core System:**
- NixOS - System configuration management
- home-manager (release-25.05) - User environment configuration

**Window Management:**
- Qtile - Python-based X11/Wayland window manager (configured in `/config/qtile/`)
- Niri - Wayland compositor (configured in `/config/niri/`)
- XWayland - X11 compatibility layer for Wayland

**Editor/Development:**
- Neovim - Primary editor with lazy.nvim plugin manager
- Zed - Secondary editor
- Fresh - Text editor (from custom flake input: `sinelaw/fresh`)

**Terminal:**
- Ghostty - Terminal emulator (from flake: `ghostty-org/ghostty`)

**Testing/Build:**
- Not applicable (dotfiles repository - no application testing framework)

**Utilities:**
- Docker - Containerization platform
- Android SDK - For React Native/Expo development (Android platforms 34-35)
- OBS Studio - Recording and streaming with obs-pipewire-audio-capture plugin

## Key Dependencies

**Critical Infrastructure:**
- nixpkgs (nixos-25.05) - NixOS package repository
- home-manager (nix-community) - User environment declarative configuration
- sops-nix (Mic92/sops-nix) - Secrets management with age encryption
- nixos-hardware (NixOS/nixos-hardware) - Hardware-specific configurations

**Editor Plugins/Extensions:**
- claude-code (ryoppippi/claude-code-overlay) - Claude Code overlay for NixOS
- ghostty (ghostty-org/ghostty) - Latest Ghostty terminal emulator

**Language Servers:**
- nixd - Nix language server
- rust-analyzer - Rust language server
- pyright - Python type checker and language server
- lua-language-server - Lua language server
- gopls - Go language server
- typescript-language-server (nodePackages) - TypeScript/JavaScript
- bash-language-server (nodePackages) - Bash language server
- sqls - SQL language server
- fish-lsp - Fish shell language server
- vscode-langservers-extracted (nodePackages) - JSON language server

**Formatters:**
- nixfmt-rfc-style - Nix formatter
- black - Python formatter
- rustfmt - Rust formatter
- stylua - Lua formatter
- prettier (nodePackages) - JavaScript/TypeScript formatter
- shfmt - Bash formatter
- goimports (gotools) - Go import formatter

**System Tools:**
- evremap - Keyboard remapping for all window managers/Wayland
- ydotool - Keyboard/mouse automation (used by waystt)
- waystt - Wayland speech-to-text utility

**Development:**
- nodejs_22 - Node.js runtime
- python3 - Python runtime
- gcc - C/C++ compiler
- jdk17 - Java Development Kit (for Android)
- eas-cli - Expo Application Services CLI
- watchman - File system event monitor

**Multimedia/Utilities:**
- mpv - Video player
- OBS Studio - Recording/streaming software
- filezilla - FTP/SFTP client
- pgcli - PostgreSQL CLI with autocomplete
- pspg - PostgreSQL pager
- v4l-utils - Webcam configuration
- nmap - Network scanner

**System Utilities:**
- bat - cat replacement with syntax highlighting
- ripgrep - Fast text search
- jq - JSON processor
- curl - HTTP client
- tmux/screen equivalents via terminal
- btop - System resource monitor
- fastfetch - System information display
- impala - WiFi TUI manager
- bluetui - Bluetooth TUI manager
- cliphist - Clipboard history manager

**Desktop/UI:**
- Brave - Browser (with custom password store)
- Firefox - Secondary browser
- Thunar - File manager with volume management and archive plugin
- Rofi Wayland - Application launcher
- Obsidian - Markdown notes application
- nwg-look - GTK theming GUI
- Polkit - Authentication agent (polkit-gnome)

**Theming:**
- Tokyonight-Dark - GTK theme
- Papirus-Dark - Icon theme
- Bibata-Modern-Classic - Cursor theme
- JetBrains Mono Nerd Font - Editor fonts
- Hack Font - Terminal fonts

## Configuration

**Environment:**
- User: `dustin` (normal user with sudo, docker, adb, kvm access)
- Home directory: `/home/dustin`
- Shell: Bash (with custom aliases and functions from `/config/bash_*.sh`)
- Timezone: America/New_York (can be overridden per-host)

**Key Environment Variables:**
- `ANDROID_HOME` - Points to Android SDK installation
- `TERMINAL` - Set to "ghostty"

**System Environment:**
- Nix Flakes enabled (experimental features)
- Unfree packages allowed
- Android SDK license accepted
- UTF-8 locale with NixOS 25.05

**Build Configuration:**
- `flake.nix` - Main entry point for NixOS and home-manager configuration
- Host-specific overrides in `hosts/{hostname}/configuration.nix`
- User-specific home configuration in `hosts/{hostname}/home.nix`
- Common shared config in `hosts/common/configuration.nix` and `hosts/common/home.nix`
- Configuration symlinks sourced from `/config/` directory

## Platform Requirements

**Development:**
- NixOS 25.05 or compatible (nixpkgs tracking)
- Flake-enabled Nix (version 2.4+)
- Git (for dotfiles management)
- SSH configured for key-based auth (handled by sops-nix)

**Production (System-wide):**
- Intel i5-6300U (mischief), AMD CPU (intrepid/vigilant) - x86_64 architecture
- EFI boot support (systemd-boot)
- 2GB+ RAM minimum (16GB+ recommended)
- Proper firmware for graphics (Intel HD 520, AMD Radeon)

**Device Support:**
- Brother HL-L2360DW printer (configured via dnssd)
- Bluetooth devices (enabled by default)
- Wayland and X11 compatible hardware
- Microsoft Surface Laptop 4 (surface-patched kernel support via nixos-hardware)
- Touchpad support via libinput

**Special Requirements:**
- Docker daemon (virtualization support enabled)
- Android development requires KVM support
- Speech-to-text requires Wayland support (waystt)
- GPU acceleration supports AMD Radeon (RADV driver) and Intel HD Graphics

---

*Stack analysis: 2026-03-20*
