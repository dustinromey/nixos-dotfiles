# External Integrations

**Analysis Date:** 2026-03-20

## APIs & External Services

**Development Tools:**
- Claude Code (Anthropic) - AI-assisted development
  - Integration: claude-code overlay from `ryoppippi/claude-code-overlay`
  - Installed package: `pkgs.claude-code`

**Printing/Device Discovery:**
- Avahi/mDNS - Network printer discovery
  - Service: `services.avahi` (enabled by default)
  - Enabled with `nssmdns4` for local network service discovery
  - Firewall: Open for printer discovery
  - Device: Brother HL-L2360DW (dnssd URI discovery)

**Remote Development:**
- xTuple ERP - Enterprise Resource Planning system
  - Integration: Custom desktop entry pointing to `~/.local/bin/xtuple`
  - Launcher: `xdg.desktopEntries.xtuple` in home configuration

## Data Storage

**File Synchronization:**
- Syncthing - Continuous file synchronization across devices
  - Service: `services.syncthing` (home-manager service)
  - State location: `~/.local/state/syncthing/`
  - Credentials: Managed via sops-nix
    - Private key: `secrets/syncthing/{hostname}.yaml`
    - Certificate: `secrets/syncthing/{hostname}.yaml`
  - Enabled on all hosts (mischief, intrepid, vigilant)

**Local Storage:**
- USB/Removable Drive Support
  - Services: `services.udisks2`, `services.gvfs`, `services.tumbler`
  - File Manager: Thunar with volume management plugin
  - Thumbnail generation: Via tumbler service
  - Virtual filesystem: gvfs for mounting and trash support

**Databases:**
- PostgreSQL (optional development)
  - Client: pgcli - PostgreSQL CLI with autocomplete
  - Pager: pspg - PostgreSQL-specific pager
  - No persistent database service configured in system
  - Language server: sqls

**File Storage:**
- Local filesystem only - no cloud storage integration
- File manager: Thunar (XFCE)
- Archive support: Via thunar-archive-plugin (zip, tar, 7z, rar)

**Caching:**
- No external caching service configured
- Application-level caching (clipboard history via cliphist)

## Authentication & Identity

**SSH Authentication:**
- SSH Host Keys - Managed via sops-nix
  - File: `/etc/ssh/ssh_host_ed25519_key`
  - Encryption: Age-based (derived from SSH host key)
  - Per-host configuration in `hosts/{hostname}/secrets.nix`

**User SSH Keys:**
- SSH private key managed via sops-nix
  - File: `~/.ssh/id_ed25519`
  - Source: `secrets/ssh/{hostname}.yaml`
  - Permissions: 0600 (user-readable only)
  - Per-host SSH configuration for mischief, intrepid, vigilant

**Secrets Management:**
- sops-nix - Encrypted secrets management
  - Encryption: Age (modern alternative to GPG)
  - Key derivation: SSH host keys generate age keys automatically
  - Age key storage: `/var/lib/sops-nix/key.txt`
  - Key generation: Automatic if missing
  - Secrets files: YAML format in `secrets/` directory structure
  - Validation: Runtime validation enabled

**Keyring:**
- GNOME Keyring - Password and credential storage
  - Service: `services.gnome-keyring` (home-manager)
  - Used by: Zed editor, browser password storage
  - Integration: dconf backend for persistent settings

**Git Authentication:**
- Git SSH-based authentication (via SSH keys managed by sops-nix)
- User configured: `dustinromey@gmail.com`
- SSH key-pair: `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`

## Monitoring & Observability

**Error Tracking:**
- None configured

**Logs:**
- Standard NixOS journald logging
- systemd service logs via `journalctl`
- Per-service logs: polkit-gnome, xwayland-satellite, evremap, etc.

**System Monitoring:**
- btop - System resource monitor (real-time CPU, memory, disk, network)
- fastfetch - System information display (hardware details)
- impala - WiFi status and connection TUI

## CI/CD & Deployment

**Hosting:**
- Local NixOS systems (3 hosts):
  - mischief: Lenovo ThinkPad X270 (test machine)
  - intrepid: Desktop (daily driver)
  - vigilant: Microsoft Surface Laptop 4

**Package Management:**
- Nix Flakes - Declarative dependency management
- Flake lock file: `flake.lock` (tracks all transitive dependencies)

**CI Pipeline:**
- None configured (dotfiles repository - no CI/CD pipeline)

**Build System:**
- NixOS rebuild commands:
  ```bash
  sudo nixos-rebuild switch --flake .#<hostname>
  home-manager switch --flake .#dustin
  ```

**Deployment Model:**
- Declarative configuration-as-code (all hosts defined in `flake.nix`)
- Multi-host management: Single flake controls mischief, intrepid, vigilant
- Reproducible builds: flake.lock ensures identical environments

## Environment Configuration

**Required Environment Variables:**
- `ANDROID_HOME` - Android SDK path (set in home.sessionVariables)
- `TERMINAL` - Terminal emulator ("ghostty")
- `AMD_VULKAN_ICD` - GPU driver selection ("RADV" for AMD systems)

**Optional Environment Variables:**
- `PATH` - Extended with `~/.local/bin` for custom scripts
- Shell initialization: Bash sources custom functions and aliases

**Configuration Files:**
- `~/.config/*/` - All application configs symlinked from `/config/` directory
  - Includes: nvim, qtile, rofi, ghostty, zed, niri, waybar, mako, obs-studio, btop, fastfetch
- `~/.bashrc` - Loads from `CLAUDE.md` defined paths
- System-wide: `/etc/nixos/` (managed by NixOS configuration)

**Secrets Location:**
- Encrypted YAML files in `secrets/` directory (not committed to git)
- Age encryption keys generated from SSH host keys
- Decrypted at runtime via sops-nix
- Per-host secrets in separate YAML files:
  - SSH keys: `secrets/ssh/{hostname}.yaml`
  - Syncthing: `secrets/syncthing/{hostname}.yaml`

## Webhooks & Callbacks

**Incoming Webhooks:**
- None configured

**Outgoing Webhooks/Callbacks:**
- None configured

**System Hooks:**
- NixOS activation scripts: Custom `/bin/bash` symlink creation
- systemd services: polkit-gnome-authentication-agent-1, xwayland-satellite, evremap (keyboard remapping)

## Network & Connectivity

**VPN:**
- Tailscale VPN - Network connectivity
  - Service: `services.tailscale` (enabled by default on all hosts)
  - Mode: Client mode (`useRoutingFeatures = "client"`)
  - Use case: Secure multi-host networking and remote access

**WiFi:**
- iwd (Intel Wireless Daemon) - Modern WiFi management
  - Service: `networking.wireless.iwd.enable` (enabled on all hosts)
  - Powers: impala WiFi TUI utility
  - Configuration: Via iwd standard config files

**Bluetooth:**
- Bluetooth support - Hardware connectivity
  - Hardware enabled: `hardware.bluetooth.enable`
  - Auto-power-on: `hardware.bluetooth.powerOnBoot`
  - TUI management: bluetui application

**Network Discovery:**
- mDNS/Avahi - Printer and service discovery
  - Enabled: `services.avahi`
  - IPv4 support: `nssmdns4`
  - Firewall: Explicitly opened

**URL Schemes:**
- Default terminal: `x-scheme-handler/terminal` → ghostty.desktop
- Web browsers: Firefox, Brave (with custom password store)

## Media & Device Integration

**Video/Webcam:**
- V4L utils - Webcam configuration
- OBS Studio - Recording and streaming
  - Plugin: obs-pipewire-audio-capture (audio from Pipewire)
  - Configuration: `/config/obs-studio/`
- Surface Camera support (vigilant): RGB webcam symlink via udev rule

**Audio:**
- PipeWire - Modern audio system
  - Service: `services.pipewire`
  - PulseAudio compatibility: Enabled
  - Plugins: OBS audio capture via PipeWire

**Display:**
- NVIDIA/AMD Graphics:
  - intrepid/vigilant: AMD Vulkan (amdvlk) with RADV driver
  - mischief: Intel HD Graphics (supported natively)
- XWayland support: For legacy X11 apps on Wayland
- Wayland compositors: Niri (primary), Qtile on X11
- Display configuration: Via nwg-look GUI or direct config

**Printing:**
- CUPS - Print server
  - Service: `services.printing` (enabled)
  - Drivers: brlaser (Brother laser printers)
  - Printer: Brother HL-L2360DW (auto-discovered via mDNS)
  - Default: "DustinPrint"

**Input Devices:**
- Keyboard remapping: evremap (evdev-based, works across X11/Wayland)
  - Configuration: Per-host in `/config/evremap/`
  - systemd service: Auto-started on boot
  - Configs: laptop.toml (mischief), rk-s70.toml (intrepid), surface.toml (vigilant)
- Touchpad support (vigilant): libinput with Surface tweaks
  - Tapping: Enabled
  - Natural scrolling: Enabled
  - Disable while typing: Enabled
- Mouse automation: ydotool (for accessibility and automation)

## Development Platform Integrations

**Container Platform:**
- Docker - Container runtime
  - Service: `virtualisation.docker.enable`
  - User access: docker group membership
  - Use case: Application containerization and deployment

**Mobile Development:**
- Android SDK - Android application development
  - Platforms: 34, 35
  - Build tools: 34.0.0, 35.0.0
  - Emulator: Included with system images
  - ABI: x86_64 (for emulation performance)
  - System images: google_apis_playstore
  - ADB access: `programs.adb.enable`
  - User group: adbusers for device access
  - React Native/Expo tooling: eas-cli, watchman

---

*Integration audit: 2026-03-20*
