# Romey NixOS Dotfiles

## What This Is

A NixOS dotfiles repository managing a complete development environment across three hosts (mischief, intrepid, vigilant). Uses Nix flakes with home-manager integration and a modular configuration structure. Includes voxtype speech-to-text with GPU acceleration and Claude AI tooling. GSD is used to plan and execute feature additions to the system.

## Core Value

Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts with shared defaults and clean per-host overrides.

## Requirements

### Validated

- Multi-host NixOS flake configuration (mischief, intrepid, vigilant) — existing
- Shared common configuration with per-host overrides — existing
- Home-manager integration with config symlinks — existing
- Neovim with LSP servers installed via Nix — existing
- Qtile window manager with vim-style keybindings — existing
- Niri Wayland compositor — existing
- Waybar status bar — existing
- Rofi app launcher — existing
- Ghostty terminal emulator — existing
- Tailscale VPN — existing
- AMD GPU support (intrepid, vigilant) and Intel GPU support (mischief) — existing
- Voxtype speech-to-text with evdev push-to-talk on all hosts — v1.0
- Vulkan GPU acceleration for voxtype on AMD hosts — v1.0
- Waybar STT status module for voxtype — v1.0
- waystt fully removed and replaced by voxtype — v1.0
- Claude Code CLI and Claude Desktop app on all hosts — v1.0

### Active

(None — define in next milestone)

### Out of Scope

- Qtile keybindings for voxtype — Niri only
- ROCm variant — Vulkan preferred for AMD GPU acceleration
- ONNX engines — standard Whisper is sufficient
- Voxtype bilingual EN/ES support — deferred to v2
- Claude MCP servers / FHS variant — not needed for basic usage

## Context

Shipped v1.0 with voxtype integration and Claude tooling. 4 phases, 5 plans executed across 3 days.
Tech additions: voxtype v0.6.4, claude-desktop (k3d3 flake), flake-utils.
Key files: flake.nix, hosts/common/home.nix, hosts/common/configuration.nix, config/waybar/.

## Constraints

- **NixOS flake**: All changes must work within the existing flake structure
- **Multi-host**: Features must either work on all hosts or have clean per-host overrides
- **Home Manager**: Prefer home-manager modules over system-level NixOS modules where available
- **Formatting**: All Nix files must pass nixfmt-rfc-style

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Vulkan over ROCm for AMD GPU accel | Vulkan is more portable across AMD/NVIDIA/Intel | Good |
| Home Manager module over NixOS module | Consistent with existing pattern, user-level config | Good |
| Evdev hotkey for push-to-talk | Niri lacks key-release events; evdev is only viable approach | Good |
| Atomic waystt removal with voxtype activation | Prevents partial state with both tools present | Good |
| lib.mkDefault for voxtype package | Allows host-specific Vulkan override on AMD hosts | Good |
| Service.Environment for PATH workarounds | home-manager path option expects attrset; Environment matches pattern | Good |
| claude-desktop (not FHS variant) | FHS only needed for MCP servers, out of scope | Good |
| No manual .desktop for Claude | k3d3 package auto-includes desktop entry | Good |

---
*Last updated: 2026-03-22 after v1.0 milestone*
