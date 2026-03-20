# Romey NixOS Dotfiles

## What This Is

A NixOS dotfiles repository managing a complete development environment across three hosts (mischief, intrepid, vigilant). Uses Nix flakes with home-manager integration and a modular configuration structure. GSD is used to plan and execute feature additions to the system.

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

### Active

- [ ] Replace waystt with voxtype for speech-to-text across all three hosts
  - Vulkan variant on AMD hosts (intrepid, vigilant)
  - CPU-only variant on mischief (Intel)
  - Push-to-talk keybinding in Niri config
  - Home Manager module integration via voxtype flake
  - Whisper base.en model, auto language detection

### Out of Scope

- Qtile keybindings for voxtype — Niri only
- ROCm variant — Vulkan preferred for AMD GPU acceleration
- ONNX engines — standard Whisper is sufficient

## Context

- Current speech-to-text uses waystt which needs to be removed
- Voxtype is a Rust binary using whisper.cpp, replacing Python-based solutions
- Voxtype has first-class NixOS support with a flake at github:peteonrails/voxtype
- The flake provides both NixOS and Home Manager modules
- Package variants: default (CPU), vulkan, rocm, onnx, onnx-cuda, onnx-rocm
- Niri supports key-release events needed for push-to-talk semantics
- User is bilingual EN/ES, auto language detection is useful

## Constraints

- **NixOS flake**: All changes must work within the existing flake structure
- **Multi-host**: Features must either work on all hosts or have clean per-host overrides
- **Home Manager**: Prefer home-manager modules over system-level NixOS modules where available
- **Formatting**: All Nix files must pass nixfmt-rfc-style

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Vulkan over ROCm for AMD GPU accel | Vulkan is more portable across AMD/NVIDIA/Intel | -- Pending |
| Home Manager module over NixOS module | Consistent with existing pattern, user-level config | -- Pending |
| Niri-only keybinding | User primarily uses Niri, skip Qtile binding | -- Pending |
| Disable voxtype built-in hotkey | Use Niri key-release events for proper push-to-talk | -- Pending |

---
*Last updated: 2026-03-20 after initialization*
