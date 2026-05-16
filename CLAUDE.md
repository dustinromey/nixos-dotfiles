# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix dotfiles repository ("Romey NixOS") managing a complete development environment across multiple hosts on both NixOS and macOS. It uses Nix flakes with home-manager integration and a modular configuration structure; macOS hosts use nix-darwin and nix-homebrew for declarative GUI app management.

## Supported Hosts

### NixOS (x86_64-linux)
- **mischief**: Lenovo ThinkPad X270, Intel i5-6300U, Intel HD 520 GPU (test machine)
- **intrepid**: Desktop, AMD CPU/GPU, 32GB RAM (daily driver)
- **vigilant**: Microsoft Surface Laptop 4, AMD CPU/GPU, 16GB RAM

### macOS (aarch64-darwin)
- **resolute**: Mac desktop
- **swift**: Mac laptop

Both macOS hosts assume Apple Silicon. To add an Intel Mac, change the system to `x86_64-darwin` in `flake.nix`.

## Common Commands

**Rebuild NixOS system (host-specific):**
```bash
# On mischief:
sudo nixos-rebuild switch --flake .#mischief

# On intrepid:
sudo nixos-rebuild switch --flake .#intrepid

# On vigilant:
sudo nixos-rebuild switch --flake .#vigilant
```

**Rebuild macOS system (nix-darwin):**
```bash
# First-time bootstrap on a new Mac (Nix + Xcode CLT must be installed first):
nix run nix-darwin -- switch --flake .#resolute   # or .#swift

# Thereafter:
darwin-rebuild switch --flake .#resolute
darwin-rebuild switch --flake .#swift
```

**Rebuild home-manager configuration:**
```bash
home-manager switch --flake .#dustin
```

**Format Nix files:**
```bash
nixfmt-rfc-style <file.nix>
```

**Check flake validity:**
```bash
nix flake check
```

## Architecture

```
flake.nix                    # Entry point: defines NixOS hosts + macOS (darwin) hosts
├── hosts/                    # NixOS hosts
│   ├── common/
│   │   └── configuration.nix  # Shared NixOS system config (boot, display, services, fonts)
│   ├── mischief/              # ThinkPad X270 (Intel)
│   │   ├── configuration.nix  # Host-specific overrides + hostname
│   │   ├── home.nix           # Imports modules/home/{shared,linux}.nix + per-host overrides
│   │   └── hardware-configuration.nix
│   ├── intrepid/              # Desktop (AMD)
│   │   ├── configuration.nix  # AMD GPU drivers + hostname
│   │   ├── home.nix
│   │   └── hardware-configuration.nix
│   └── vigilant/              # Surface Laptop (AMD)
│       ├── configuration.nix  # AMD GPU + touchpad + hostname
│       ├── home.nix
│       └── hardware-configuration.nix
├── darwin/                   # macOS (nix-darwin) hosts
│   ├── common.nix             # Shared darwin system config (defaults, keyboard, Homebrew)
│   ├── resolute/              # Mac desktop
│   │   ├── configuration.nix  # Hostname + per-host overrides
│   │   └── home.nix           # Imports modules/home/{shared,darwin}.nix
│   └── swift/                 # Mac laptop
│       ├── configuration.nix
│       └── home.nix
├── modules/
│   └── home/                  # Reusable home-manager modules
│       ├── shared.nix         # Cross-platform: CLIs, LSPs, git, bash, portable configs
│       ├── linux.nix          # Linux-only: WMs (qtile/niri), Wayland utils, GTK, Android
│       └── darwin.nix         # macOS-only home-manager bits
├── config/                    # Shared application configs (symlinked to ~/.config/)
│   ├── nvim/                 # Primary editor (Lua config, lazy.nvim)
│   ├── qtile/                # Window manager (Python, vim-style keybinds)
│   ├── rofi/                 # App launcher (Tokyo Night theme)
│   ├── ghostty/              # Terminal emulator
│   ├── zed/                  # Secondary editor
│   ├── niri/                 # Wayland compositor
│   ├── waybar/               # Status bar
│   └── fastfetch/            # System info display
└── config-overrides/          # Per-host config overrides (optional)
    ├── intrepid/
    └── vigilant/
```

## Key Design Decisions

- **Modular multi-host setup**: Common configuration in `hosts/common/`, host-specific overrides in `hosts/<hostname>/`
- **LSP servers installed via Nix** (home.nix), not Mason - maintains full system control
- **Config symlinks**: All app configs live in `config/` and are symlinked to `~/.config/` by home-manager
- **Hardware-specific configurations**: AMD GPU support for intrepid/vigilant, Intel for mischief
- **Shared by default**: All hosts share the same base configuration unless overridden
- **lib.mkDefault**: Used in common config to allow host-specific overrides
- **Neovim**: Uses lazy.nvim package manager, LSP keybinds are `gd` (definition), `gr` (references), `K` (hover), `<F2>` (rename), `<F3>` (format), `<F4>` (code actions)
- **Window manager (Linux)**: Qtile with vim-style navigation (Super+hjkl), Super+Space for Rofi launcher
- **Window manager (macOS)**: OmniWM (Niri-style scrolling columns + Hyprland dwindle), installed via the `BarutSRB/tap` Homebrew tap

## Design Notes — macOS / nix-darwin

These are decisions and gotchas specific to the darwin side of the flake. Read this before touching `darwin/` or the darwin inputs in `flake.nix`.

- **Apple Silicon assumed.** Both Macs evaluate as `aarch64-darwin`. To add an Intel Mac, change its `system` in `flake.nix` to `x86_64-darwin`.
- **GUI apps via Homebrew, not Nix.** macOS GUI builds in nixpkgs are unreliable; nix-darwin's `homebrew` module declaratively drives `brew install`. `cleanup = "uninstall"` removes any cask not in the declared list while preserving user data; flip to `"zap"` for stricter parity.
- **`nix-homebrew` is pinned.** The current `main` requires `ruby_4_0`, which nixpkgs-25.05 doesn't ship (it only goes up to `ruby_3_4`). The flake pins the last commit before that bump. **Unpin when upgrading to nixpkgs-25.11+.**
- **Ctrl ↔ Cmd swap uses `userKeyMapping`.** nix-darwin has no `swapLeftCtrlAndLeftCmd` option — its built-in swaps are limited to Cmd↔Alt and Ctrl↔Fn. The Ctrl↔Cmd swap is implemented in `darwin/common.nix` via `system.keyboard.userKeyMapping` (HID usage IDs `30064771296` / `30064771299` = `0x7000000E0` / `0x7000000E3`). Nix has no hex literals — keep these as decimal.
- **`fresh` editor is Linux-only.** Its flake only exposes Linux systems, so it's wrapped in `lib.optionals stdenv.isLinux` in `modules/home/shared.nix`. Remove the conditional if upstream adds darwin support.
- **`waystt` overlay is NixOS-only.** Scoped inside `mkHost` (as `linuxOverlay`); darwin evaluation never sees it.
- **Determinate Systems Nix installer conflict.** If a Mac was set up with the Determinate Systems installer (recommended), nix-darwin's own Nix-daemon management can conflict. Set `nix.enable = false;` in `darwin/common.nix` (or the per-host file) on that machine.
- **Cask substitutions** (where the Linux package name does not map cleanly):
  - `mpv` → cask `iina` (no `mpv` cask exists; IINA is the native front-end). `mpv` is also installed as a CLI formula.
  - `filezilla` → cask `cyberduck` (FileZilla was pulled from Homebrew over bundled-installer concerns).
  - `syncthing` → cask `syncthing-app` (the `syncthing` formula is a CLI service).
  - `tailscale` → cask `tailscale-app` (the bare `tailscale` cask was deprecated).
- **Cowork has no Homebrew cask** as of 2026-05-16. Install manually from Anthropic until a tap exists; a TODO marker lives in `darwin/common.nix`.
- **OmniWM requires manual macOS permissions.** Accessibility + Input Monitoring + "Displays have separate Spaces" must be off — see the bootstrap section below.

## Adding a New NixOS Host

1. Create directory: `mkdir -p hosts/newhost`
2. Create `hosts/newhost/configuration.nix`:
   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [
       ./hardware-configuration.nix
       ../common/configuration.nix
     ];
     networking.hostName = "newhost";
     # Add host-specific overrides here
   }
   ```
3. Create `hosts/newhost/home.nix`:
   ```nix
   { config, pkgs, inputs, ... }:
   {
     imports = [
       ../../modules/home/shared.nix
       ../../modules/home/linux.nix
     ];
     # Add host-specific home overrides here
   }
   ```
4. Generate hardware config on the target machine:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/newhost/hardware-configuration.nix
   ```
5. Add to `flake.nix` outputs:
   ```nix
   nixosConfigurations.newhost = mkHost "newhost" "x86_64-linux";
   ```

## Bootstrapping a Mac (First Time)

Before `nix run nix-darwin` will do anything, the Mac needs Xcode Command Line Tools and Nix installed. The flake already defines `resolute` (desktop) and `swift` (laptop); this walkthrough applies to either.

1. **Install Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```

2. **Install Nix** (Determinate Systems installer is the maintained recommendation):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   If you use this installer, see the "Determinate Systems Nix installer conflict" note above — you may need `nix.enable = false;` in `darwin/common.nix`.

3. **Clone the repo:**
   ```bash
   git clone git@github.com:dustinromey/nixos-dotfiles.git ~/nixos-dotfiles
   cd ~/nixos-dotfiles
   ```

4. **First switch** (this also bootstraps Homebrew via nix-homebrew):
   ```bash
   nix run nix-darwin -- switch --flake .#resolute   # or .#swift
   ```
   Thereafter: `darwin-rebuild switch --flake .#<host>`.

5. **Grant macOS permissions OmniWM needs** (these cannot be set declaratively — flip them by hand once):
   - **Accessibility:** System Settings → Privacy & Security → Accessibility → enable OmniWM.
   - **Input Monitoring:** System Settings → Privacy & Security → Input Monitoring → enable OmniWM.
   - **Displays have separate Spaces** must be **off**: System Settings → Desktop & Dock → Mission Control.

6. **Install Cowork manually** (no Homebrew cask exists). Download from Anthropic.

7. **Log out / restart affected apps** after `darwin-rebuild switch` if you changed `CustomUserPreferences` (keyboard shortcuts, etc.) — `cfprefsd` caches preferences and shortcuts are read at login / app launch.

## Adding a New macOS Host

For a third Mac beyond `resolute` and `swift`:

1. Create directory: `mkdir -p darwin/newmac`
2. Create `darwin/newmac/configuration.nix`:
   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [ ../common.nix ];
     networking.hostName = "newmac";
     # Per-host darwin overrides here
   }
   ```
3. Create `darwin/newmac/home.nix`:
   ```nix
   { config, pkgs, inputs, ... }:
   {
     imports = [
       ../../modules/home/shared.nix
       ../../modules/home/darwin.nix
     ];
   }
   ```
4. Add to `flake.nix` outputs:
   ```nix
   darwinConfigurations.newmac = mkDarwinHost "newmac" "aarch64-darwin";
   ```
5. Follow the "Bootstrapping a Mac" steps above on the new machine, substituting `newmac` for the hostname.

## Installed Language Servers

Defined in modules/home/shared.nix (cross-platform): nixd, nil, pyright, rust-analyzer, gopls, typescript-language-server, lua-language-server, bash-language-server, vscode-langservers-extracted (JSON), sqls, fish-lsp

## Installed Formatters

nixfmt-rfc-style, black (Python), rustfmt, stylua (Lua), prettier (JS/TS), shfmt (Bash), goimports (Go)

## Git Commit Style

When making commits:
- Use simple commit messages without AI attribution footers
- Do not include "Generated with Claude Code" or "Co-Authored-By" lines
- Format: `[type]: [description]` (e.g., `feat: add Fresh text editor`)
