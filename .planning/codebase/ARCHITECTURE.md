# Architecture

**Analysis Date:** 2026-03-20

## Pattern Overview

**Overall:** Multi-host declarative infrastructure with layered configuration (system + home-manager)

**Key Characteristics:**
- Modular Nix flakes with host-specific overrides
- Shared base configuration in `hosts/common/` with `lib.mkDefault` allowing host-specific overrides
- Declarative package management via Nix (no imperative package managers on system level)
- Unified dotfiles repository managing both NixOS system config and user home configuration
- Hardware-specific driver configuration per host (GPU support, keyboard remapping)
- Config symlinks strategy: all app configs in `config/` symlinked to `~/.config/` by home-manager

## Layers

**System Configuration (NixOS):**
- Purpose: Define system-wide services, bootloader, hardware drivers, and global packages
- Location: `flake.nix`, `hosts/*/configuration.nix`, `hosts/common/configuration.nix`
- Contains: Boot configuration, services (display manager, sound, Bluetooth, Docker), firmware, printer setup, security policies
- Depends on: nixpkgs inputs, nixos-hardware, sops-nix for secrets
- Used by: Home-manager (via home-manager NixOS module)

**Home Configuration (home-manager):**
- Purpose: Define per-user packages, programs, environment variables, and symlinked configs
- Location: `hosts/*/home.nix`, `hosts/common/home.nix`
- Contains: User packages (LSPs, formatters, dev tools), language-specific tools, desktop entries, home state
- Depends on: System configuration (useGlobalPkgs = true), inputs (Fresh editor, custom packages)
- Used by: End user environment

**Application Configs:**
- Purpose: Define application behavior and appearance (symlinked to ~/.config/)
- Location: `config/*/` (nvim, qtile, niri, rofi, ghostty, waybar, zed, mako, evremap, obs-studio)
- Contains: Editor configs, window manager keybinds, terminal config, key remapping definitions
- Depends on: Home-manager symlink mechanism in `hosts/common/home.nix`
- Used by: Applications (Neovim, Qtile, Niri, Rofi, etc.)

**Hardware-Specific Overrides:**
- Purpose: Device-specific configuration (GPU drivers, input handling, keyboard remapping)
- Location: `hosts/mischief/configuration.nix`, `hosts/intrepid/configuration.nix`, `hosts/vigilant/configuration.nix`
- Contains: GPU driver selection, keyboard remapping rules, touchpad settings, hardware-specific services
- Depends on: Common configuration, hardware-configuration.nix (generated per host)
- Used by: System-level services during boot and runtime

**Custom Package Definitions:**
- Purpose: Build and provide packages not available in nixpkgs
- Location: `packages/waystt/default.nix` (custom overlay applied in flake.nix)
- Contains: Rust package build definitions with GPU acceleration (Vulkan)
- Depends on: nixpkgs build infrastructure, upstream source repos
- Used by: System packages via overlay mechanism

## Data Flow

**System Boot & Activation:**

1. `flake.nix` entry point defines three hosts using `mkHost` helper
2. Each host imports: `hosts/{hostname}/configuration.nix` + `hosts/{hostname}/hardware-configuration.nix` + `hosts/common/configuration.nix`
3. Common config defines shared services/packages with `lib.mkDefault` allowing overrides
4. Host-specific config imports common, then applies hostname and hardware-specific overrides
5. home-manager module imported in system config applies `hosts/{hostname}/home.nix`
6. Home config imports `hosts/common/home.nix` (shares common packages/settings)
7. Symlink mechanism (`create_symlink` in `hosts/common/home.nix`) creates `~/.config/{app}/` pointing to `config/{app}/`
8. Secrets loaded via sops-nix (referenced in `hosts/*/secrets.nix`)
9. System activates with complete user environment and application configs in place

**Configuration Override Precedence:**

1. Flake inputs (nixpkgs, home-manager, nixos-hardware)
2. Custom overlay applied to nixpkgs (packages/waystt)
3. Common configuration (base settings for all hosts)
4. Host-specific configuration (overrides common via imports)
5. home-manager user configuration (per-host home.nix → common home.nix)
6. Application configs (via symlinks from config/ to ~/.config/)

**State Management:**

- **Immutable config**: All configs declared in Nix
- **Home state**: Managed by home-manager (files/directories/symlinks)
- **System state**: Managed by nixos-rebuild (generations tracked, garbage collection weekly)
- **User data**: Managed by Syncthing (enabled in `hosts/common/home.nix`)
- **Secrets**: Managed by sops-nix (keys in `secrets/` directory, values in host-specific `secrets.nix`)

## Key Abstractions

**mkHost helper:**
- Purpose: Reduce repetition when defining host configurations
- File: `flake.nix` (lines 35-56)
- Pattern: Encapsulates import logic, module injection, overlay application, home-manager setup
- Usage: Creates three identical structures (mischief, intrepid, vigilant) with minimal config difference

**create_symlink function:**
- Purpose: Create symlinks from `config/` to `~/.config/` without copying files
- File: `hosts/common/home.nix` (lines 4-6)
- Pattern: `config.lib.file.mkOutOfStoreSymlink` ensures live edits in dotfiles sync to application configs
- Usage: Applied via `xdg.configFile` mapAttrs pattern (lines 227-232)

**configs attribute set:**
- Purpose: Centralized mapping of application configs to be symlinked
- File: `hosts/common/home.nix` (lines 18-31)
- Pattern: Single source of truth for which config directories to link
- Usage: Referenced in `xdg.configFile` to avoid repetition

**Android SDK composition:**
- Purpose: Build consistent Android development environment
- File: `hosts/common/home.nix` (lines 8-16)
- Pattern: Uses nixpkgs.androidenv.composeAndroidPackages with specific versions and features
- Usage: Provides ANDROID_HOME environment variable for React Native/Expo development

## Entry Points

**Flake evaluation:**
- Location: `flake.nix`
- Triggers: `nixos-rebuild switch --flake .#hostname`, `home-manager switch --flake .#dustin`
- Responsibilities: Define inputs (nixpkgs, home-manager), create host configurations via mkHost, apply custom package overlay

**NixOS system activation:**
- Location: `hosts/{hostname}/configuration.nix`
- Triggers: `sudo nixos-rebuild switch --flake .#{hostname}`
- Responsibilities: Import hardware config, import common config, apply host-specific overrides, activate services/packages

**home-manager activation:**
- Location: `hosts/{hostname}/home.nix`
- Triggers: `home-manager switch --flake .#dustin` (embedded in nixos-rebuild when using NixOS module)
- Responsibilities: Import common home config, apply host-specific home overrides, create symlinks for application configs

**Application initialization:**
- Location: Application entry points (e.g., `config/nvim/init.lua` for Neovim, `config/qtile/config.py` for Qtile)
- Triggers: Application startup
- Responsibilities: Load configs, initialize keybinds, set up LSPs and formatters

## Error Handling

**Strategy:** Declarative validation + runtime feedback

**Patterns:**
- Nix evaluation errors caught at build time (type checking, syntax validation)
- Home-manager symlink failures create backups (backupFileExtension = "backup" in flake.nix line 52)
- Service failures logged to systemd journal (ExecStart failures for evremap, polkit-gnome, xwayland-satellite)
- Application config errors reported at startup (Neovim LSP, Rofi parsing)

## Cross-Cutting Concerns

**Logging:**
- System services: systemd journal (`journalctl -u <service>`)
- Applications: Neovim logs in `~/.local/state/nvim/log`, Zed in `~/.local/share/zed/logs`
- Wayland session: XDG_LOG_HOME or fallback to syslog

**Validation:**
- Nix syntax: Validated at flake evaluation time
- Hardware config: Generated by `nixos-generate-config --show-hardware-config`
- Secrets: Validated by sops-nix during system activation
- Application configs: Parsed at application startup (Neovim init, Qtile init, etc.)

**Authentication:**
- System user: `dustin` with groups (wheel, input, docker, video, adbusers, kvm)
- Home-manager: Runs as `dustin` user under `home-manager.users.dustin`
- Secrets management: sops-nix handles encrypted secrets in `secrets/` directory
- Service auth: Polkit for privileged operations (mounting, printing), gnome-keyring for application secrets (Zed)

---

*Architecture analysis: 2026-03-20*
