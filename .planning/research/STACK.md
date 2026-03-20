# Stack Research

**Domain:** NixOS speech-to-text integration (voxtype brownfield migration)
**Researched:** 2026-03-20
**Confidence:** MEDIUM — voxtype flake verified via direct GitHub inspection; niri key-release limitation verified via official docs; some NixOS module option details inferred from source inspection

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| voxtype flake | v0.6.4 (latest) | Speech-to-text daemon | Actively maintained Rust binary with first-class NixOS and Home Manager modules; replaces hand-rolled waystt package with declarative config; ships both CPU and Vulkan variants as separate flake outputs |
| `voxtype.packages.vulkan` | v0.6.4 | AMD GPU-accelerated transcription | Pre-built binary with Vulkan bundled; no custom Nix derivation needed unlike waystt; use on intrepid and vigilant (AMD GPU) |
| `voxtype.packages.default` | v0.6.4 | CPU-only transcription | Intel HD 520 on mischief has no usable Vulkan for inference; CPU-only avoids driver complexity on the test machine |
| `homeManagerModules.default` | v0.6.4 | Declarative user config + systemd service | Generates `~/.config/voxtype/config.toml` from Nix attrset; handles systemd user service lifecycle; prevents config drift across hosts |
| `nixosModules.default` | v0.6.4 | System-level ydotool daemon + input group | Manages `programs.ydotool.enable` and typing backend selection at the OS level; already needed for waystt so no new system dependency |
| Whisper base.en model | — | Transcription model | 142 MB; fastest model with good accuracy for conversational English; `.en` suffix gives 10-15% better performance on English-only input |

### Supporting Libraries (already present in repo)

| Library | Purpose | Notes |
|---------|---------|-------|
| ydotool | Types transcribed text via uinput | Already enabled via `programs.ydotool.enable` in common config; voxtype wraps it automatically in its bundled packages |
| wtype | Alternative typer for Wayland (XDG) | Bundled inside voxtype's wrapped packages; no separate Nix declaration needed |
| PipeWire + PulseAudio compat | Audio capture | Already enabled in common config (`services.pipewire.pulse.enable = true`); voxtype uses the PulseAudio interface |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `voxtype setup --download` | Downloads Whisper model on first run | Run once per host; stores model at `~/.local/share/voxtype/models/`; only network access voxtype needs |
| `voxtype status` | Confirms daemon is running and reports engine/model | Use to verify post-deploy; also confirms Vulkan is active on AMD hosts |
| `nix flake update voxtype` | Keep voxtype flake input current | Pin to a specific rev for stability; unpin to track releases |

---

## Flake Integration

### How to Wire In the Flake

Add voxtype as a flake input in `flake.nix`:

```nix
inputs = {
  # existing inputs ...
  voxtype.url = "github:peteonrails/voxtype";
  voxtype.inputs.nixpkgs.follows = "nixpkgs";
};
```

Pass `inputs` to both NixOS modules and Home Manager modules (already done via `extraSpecialArgs = { inherit inputs; }`).

### NixOS Module Usage (common/configuration.nix)

```nix
imports = [
  inputs.voxtype.nixosModules.default
];

programs.voxtype = {
  enable = true;
  # package is not set here; set per-host or in home manager
};
```

The NixOS module handles: adding the package to `environment.systemPackages`, enabling `ydotool`, and adding `dustin` to the `input` group (required for evdev hotkey fallback — needed on niri, see below).

### Home Manager Module Usage (host-specific home.nix)

AMD hosts (intrepid, vigilant):
```nix
imports = [ inputs.voxtype.homeManagerModules.default ];

programs.voxtype = {
  enable = true;
  package = inputs.voxtype.packages.x86_64-linux.vulkan;
  model.name = "base.en";
  service.enable = true;
  settings = {
    hotkey.enabled = false;  # use evdev directly; see niri note below
    whisper.language = ["en" "es"];  # constrained bilingual detection
  };
};
```

CPU host (mischief):
```nix
programs.voxtype = {
  enable = true;
  package = inputs.voxtype.packages.x86_64-linux.default;
  model.name = "base.en";
  service.enable = true;
  settings = {
    hotkey.enabled = false;
    whisper.language = ["en" "es"];
  };
};
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `voxtype` (peteonrails) | `waystt` (sevos) | Never — waystt is unmaintained at v0.3.0 with no NixOS module; required a hand-rolled Nix derivation with Vulkan patches; no bilingual support or TOML config |
| `voxtype` | `whisper-standalone` (CLI wrapper) | Only if you need server mode or want to share one transcription backend across multiple apps |
| `model.name = "base.en"` (declarative download) | `model.path` pointing to a local file | When the model is already downloaded or you want to avoid HuggingFace fetch at activation time |
| Constrained `language = ["en", "es"]` | `language = "auto"` (full auto) | Full auto risks misidentification on short phrases; constrained detection is faster and more accurate for known bilingual users |
| `voxtype.packages.vulkan` on AMD | `voxtype.packages.rocm` | ROCm has more complex system dependencies; Vulkan is simpler, ships pre-built, and sufficient for real-time base.en inference |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `waystt` (sevos/waystt) | Abandoned; last release 2023; no NixOS module; required manual Cargo.toml patching for Vulkan (see `packages/waystt/default.nix`); no configuration beyond CLI flags | `voxtype` |
| `packages.onnx` / Moonshine / Parakeet | English-only; no bilingual support; more complex ONNX runtime dependency chain | `voxtype` with Whisper engine and `base.en` model |
| `packages.rocm` on AMD | Requires full ROCm stack (heavy); Vulkan is sufficient for inference latency at base.en size | `packages.vulkan` |
| `hotkey.enabled = true` (evdev built-in) with niri | Niri does NOT support key-release compositor bindings (confirmed in official niri docs); to get push-to-talk with niri you MUST use evdev mode, which requires the `input` group — NOT the compositor path used by Hyprland/Sway/River | Keep `hotkey.enabled = true` (default) and use evdev; ensure `dustin` is in `extraGroups = ["input"]` (already true in common config) |
| `language = "auto"` for bilingual use | Whisper frequently misidentifies short Spanish utterances as other Romance languages in full-auto mode | `language = ["en", "es"]` (constrained detection) |

---

## Stack Patterns by Variant

**AMD hosts (intrepid, vigilant) — GPU-accelerated:**
- Use `inputs.voxtype.packages.x86_64-linux.vulkan`
- Vulkan package bundles whisper.cpp compiled with Vulkan support
- No additional system packages needed (Vulkan loader already present for GPU drivers)

**Intel host (mischief) — CPU-only:**
- Use `inputs.voxtype.packages.x86_64-linux.default`
- Intel HD 520 is Gen 9 (2016); Vulkan inference on it is slower than CPU for small models
- CPU path has no additional dependencies

**Niri push-to-talk keybinding (all hosts):**
- Niri does not support key-release `spawn` actions — there is no `bindr` equivalent (confirmed in official niri wiki)
- Use voxtype's built-in evdev hotkey (`hotkey.enabled = true`, which is default)
- Evdev requires `input` group membership — already in `users.users.dustin.extraGroups` in common config
- Replace current niri toggle-script bindings (Mod+R / Mod+Shift+R) with a single push-to-talk key via voxtype's own hotkey config
- Niri binds for manual start/stop remain possible using `voxtype record start` / `voxtype record stop` if toggle mode is preferred over push-to-talk

**Bilingual EN/ES (all hosts):**
- Use `whisper.language = ["en", "es"]` in `settings`
- base.en model works acceptably for Spanish with constrained detection; upgrade to `small` or `small.en` if accuracy degrades on Spanish

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| voxtype v0.6.4 | nixpkgs nixos-25.05 | Flake uses `nixpkgs/nixos-unstable` as its own input; set `voxtype.inputs.nixpkgs.follows = "nixpkgs"` to use the repo's pinned 25.05 and avoid duplicate nixpkgs evaluation |
| voxtype v0.6.4 | home-manager release-25.05 | Home Manager module uses standard `config.lib.file`, `pkgs`, `lib` — no unstable-only APIs observed |
| whisper-rs 0.16.0 | clang 22+ | v0.6.4 updated whisper-rs to unblock builds on newer clang (was a known issue in earlier versions) |
| `base.en` model | Whisper engine only | ONNX engines use `model.path` to a directory, not a named model; do not mix engine and model.name |

---

## Migration: waystt Removal Checklist

These locations reference waystt and must be updated:

| File | Change Needed |
|------|--------------|
| `flake.nix` | Remove `overlay` block and `waystt = final.callPackage ...`; add `voxtype` flake input |
| `flake.nix` | Remove `nixpkgs.overlays = [ overlay ]` from `mkHost` |
| `packages/waystt/default.nix` | Delete entire directory |
| `hosts/common/configuration.nix` | Remove `waystt` from `environment.systemPackages`; add voxtype NixOS module import |
| `hosts/common/configuration.nix` | `programs.ydotool.enable` can stay — voxtype still uses it |
| `config/niri/config.kdl` | Replace Mod+R / Mod+Shift+R waystt bindings with voxtype push-to-talk config (or remove if using evdev hotkey) |
| `config/waybar/scripts/stt-status.sh` | Update to query `voxtype status` instead of waystt process |
| `bin/stt-toggle.sh` | Either delete (replaced by voxtype's built-in push-to-talk) or rewrite to call `voxtype record start/stop` |
| `hosts/*/home.nix` | Add voxtype Home Manager module config (host-specific `package` selection) |

---

## Sources

- [github.com/peteonrails/voxtype](https://github.com/peteonrails/voxtype) — README, flake.nix, nix/home-manager-module.nix, nix/nixos-module.nix inspected directly (MEDIUM confidence — source code read, not official published docs)
- [voxtype.io/news](https://voxtype.io/news/) — v0.6.4 release notes (MEDIUM confidence — official project site)
- [github.com/peteonrails/voxtype/releases](https://github.com/peteonrails/voxtype/releases) — current release v0.6.4 dated 2025-03-20 confirmed (MEDIUM confidence)
- [github.com/peteonrails/voxtype/blob/main/docs/CONFIGURATION.md](https://github.com/peteonrails/voxtype/blob/main/docs/CONFIGURATION.md) — language constrained detection, hotkey config, GPU settings (MEDIUM confidence — official project docs)
- [github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings) — niri key-release limitation confirmed (HIGH confidence — official niri wiki)
- [variety4me.github.io/niri_docs](https://variety4me.github.io/niri_docs/Configuration-Key-Bindings/) — corroborates niri has no on-release binding (MEDIUM confidence — community mirror of official docs)
- `nixos-dotfiles/packages/waystt/default.nix` — waystt current state, hand-rolled derivation (HIGH confidence — read directly from repo)
- `nixos-dotfiles/hosts/common/configuration.nix` — existing system config, groups, ydotool, waystt reference (HIGH confidence — read directly from repo)
- `nixos-dotfiles/config/niri/config.kdl` — current STT keybinding pattern (HIGH confidence — read directly from repo)

---

*Stack research for: NixOS voxtype speech-to-text integration (replacing waystt)*
*Researched: 2026-03-20*
