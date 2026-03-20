# Architecture Research

**Domain:** NixOS flake-based multi-host dotfiles — speech-to-text integration (voxtype)
**Researched:** 2026-03-20
**Confidence:** HIGH (direct source inspection of both flake.nix outputs and existing repo structure)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        flake.nix (entry point)                    │
│  inputs: voxtype.url = "github:peteonrails/voxtype"               │
├──────────────────────────────────────────────────────────────────┤
│                        mkHost pattern                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐ │
│  │   mischief    │  │   intrepid    │  │       vigilant        │ │
│  │  (Intel/CPU)  │  │  (AMD/Vulkan) │  │   (AMD/Vulkan)        │ │
│  └──────┬────────┘  └──────┬────────┘  └──────────┬────────────┘ │
│         │                  │                       │             │
├─────────┴──────────────────┴───────────────────────┴─────────────┤
│                    NixOS module layer                             │
│  ┌──────────────────────────┐   ┌──────────────────────────────┐ │
│  │ voxtype.nixosModules     │   │ hosts/common/configuration   │ │
│  │   .default               │   │  programs.ydotool.enable     │ │
│  │ (pkg install + ydotool   │   │  users.extraGroups: input    │ │
│  │  integration)            │   │  hardware.uinput.enable      │ │
│  └──────────────────────────┘   └──────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                    home-manager module layer                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ voxtype.homeManagerModules.default                           │ │
│  │  programs.voxtype.enable = true                              │ │
│  │  programs.voxtype.engine = "whisper" | "parakeet" | ...      │ │
│  │  programs.voxtype.package = packages.default | .vulkan       │ │
│  │  programs.voxtype.model.name = "large-v3-turbo"              │ │
│  │  programs.voxtype.settings = { ... }  (TOML config)          │ │
│  │  programs.voxtype.service.enable = true                      │ │
│  └──────────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                    runtime / compositor layer                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │  niri (Wayland)│  │    waybar      │  │  PipeWire audio    │  │
│  │  keybindings   │  │  custom/stt    │  │  mic capture       │  │
│  │  (record       │  │  status widget │  │                    │  │
│  │  start/stop)   │  │                │  │                    │  │
│  └────────────────┘  └────────────────┘  └────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `flake.nix` inputs | Pins voxtype flake version for reproducibility | `voxtype.url = "github:peteonrails/voxtype"` |
| `voxtype.nixosModules.default` | System-wide: package install, ydotool daemon integration, input group | Imported in `hosts/common/configuration.nix` or per-host `configuration.nix` |
| `voxtype.homeManagerModules.default` | User-level: daemon service, model download, TOML config generation, runtime deps in PATH | Imported in `hosts/common/home.nix` |
| `programs.voxtype.package` | Selects CPU vs Vulkan build variant | Per-host override in `hosts/<hostname>/home.nix` |
| `programs.ydotool.enable` | System service enabling ydotool backend for text injection | Already present in `hosts/common/configuration.nix` |
| `config/niri/config.kdl` | Compositor keybindings — `voxtype record start` / `voxtype record stop` | Binds on key press and key release for push-to-talk |
| `config/waybar/config.jsonc` | Status widget showing recording state | `custom/stt` module with exec script |
| `config/waybar/scripts/stt-status.sh` | Polls voxtype daemon state for waybar | Needs update from waystt protocol to voxtype |

## Recommended Project Structure

```
flake.nix
├── inputs.voxtype.url = "github:peteonrails/voxtype"
│
hosts/
├── common/
│   ├── configuration.nix    # + voxtype.nixosModules.default import
│   │                        # programs.ydotool.enable already present
│   │                        # users.extraGroups includes "input" already
│   └── home.nix             # + voxtype.homeManagerModules.default import
│                            #   programs.voxtype.enable = true
│                            #   programs.voxtype.package = default (CPU)
│                            #   programs.voxtype.service.enable = true
│                            #   programs.voxtype.model.name = "..."
│                            #   programs.voxtype.settings = { ... }
├── mischief/
│   └── home.nix             # no override — inherits CPU default
├── intrepid/
│   └── home.nix             # programs.voxtype.package = inputs.voxtype.packages.${system}.vulkan
└── vigilant/
    └── home.nix             # programs.voxtype.package = inputs.voxtype.packages.${system}.vulkan

config/
├── niri/config.kdl          # update keybindings: voxtype record start / stop
└── waybar/
    ├── config.jsonc         # custom/stt module stays; exec script path may change
    └── scripts/stt-status.sh  # update to query voxtype daemon state
```

### Structure Rationale

- **Common home.nix for enable + service:** All three hosts run voxtype; the daemon, model, and settings belong in common.
- **Per-host home.nix for package variant:** Only `intrepid` and `vigilant` have AMD GPUs with Vulkan. `mischief` (Intel HD 520) stays CPU. This is the same pattern used for existing host-specific overrides.
- **nixosModules in common/configuration.nix:** System-level concerns (ydotool socket permissions, input group) are already present. The voxtype nixosModule reinforces/codifies this.
- **Niri config stays in config/:** Symlinked to `~/.config/niri/config.kdl`. Keybinding change is a text edit, not a Nix change.
- **Waybar scripts stay in bin/ or config/waybar/scripts/:** Already symlinked via home-manager.

## Architectural Patterns

### Pattern 1: Flake Input + Module Consumption

**What:** Add voxtype flake as an input in `flake.nix`, pass it through `specialArgs`/`extraSpecialArgs`, then import its modules in the appropriate host/common config files.

**When to use:** Always — this is the canonical NixOS flake pattern. The existing repo already does this for `claude-code`, `fresh`, `sops-nix`, `ghostty`, and `nixos-hardware`.

**Trade-offs:** Version is pinned in `flake.lock` — reproducible, but requires `nix flake update` to get new voxtype releases. This is a feature, not a bug.

**Example:**
```nix
# flake.nix inputs
voxtype.url = "github:peteonrails/voxtype";
voxtype.inputs.nixpkgs.follows = "nixpkgs";  # prevent double nixpkgs

# flake.nix mkHost — already passes inputs via specialArgs/extraSpecialArgs
# No change needed to mkHost itself

# hosts/common/configuration.nix
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.voxtype.nixosModules.default
  ];
  programs.voxtype.enable = true;
}

# hosts/common/home.nix
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.voxtype.homeManagerModules.default
  ];
  programs.voxtype = {
    enable = true;
    service.enable = true;
    model.name = "large-v3-turbo";
    settings = {
      hotkey.enabled = false;  # disable built-in; use compositor bindings
      output.mode = "type";
    };
  };
}
```

### Pattern 2: Per-Host Package Variant Override

**What:** Common config sets `programs.voxtype.package` to the CPU default. Hosts with AMD/Vulkan GPUs override to the vulkan variant in their `home.nix`.

**When to use:** When hardware-specific build variants exist. Same pattern as `hardware.graphics.extraPackages` already used in `intrepid` and `vigilant` configuration.nix.

**Trade-offs:** Small duplication across two host files; avoids a complex conditional. Clear and explicit.

**Example:**
```nix
# hosts/intrepid/home.nix (and vigilant/home.nix)
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];
  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
```

### Pattern 3: Compositor Push-to-Talk via record start/stop

**What:** Disable voxtype's built-in hotkey listener (`hotkey.enabled = false`) and drive it entirely from niri bindings using `voxtype record start` on keypress and `voxtype record stop` on keyrelease.

**When to use:** Always on Niri (and any Wayland compositor). Voxtype's built-in hotkey uses evdev directly, which can conflict with compositor-level grabs. The compositor-driven approach is the recommended pattern from voxtype docs.

**Trade-offs:** Requires two bind lines in niri config (press + release). Works correctly with push-to-talk semantics. The existing niri config already uses this two-line pattern for `waystt` (`stt-toggle.sh`); this replaces that script with direct voxtype commands.

**Example:**
```kdl
# config/niri/config.kdl
Mod+R hotkey-overlay-title="STT (type)" {
    spawn "voxtype" "record" "start";
}
// On key release:
Mod+R release=true {
    spawn "voxtype" "record" "stop";
}
```

Note: Niri's exact syntax for key-release binds requires verification against current niri docs — the existing config uses a script approach (`stt-toggle.sh`) that may need updating to pure `voxtype record start/stop` calls or a thin wrapper.

## Data Flow

### Recording Flow (push-to-talk)

```
User presses Mod+R
    |
    v
niri compositor
    |
    v
spawn "voxtype record start"
    |
    v
voxtype daemon (systemd user service)
    |-- reads mic audio via PipeWire
    |-- runs Whisper inference (CPU or Vulkan GPU)
    v
User releases Mod+R
    |
    v
spawn "voxtype record stop"
    |
    v
voxtype daemon produces transcribed text
    |
    +--[mode: type]--> wtype injects text at cursor position
    |
    +--[mode: clipboard]--> wl-copy to clipboard
    |
    +--[mode: paste]--> saves clipboard, pastes, restores clipboard
    v
Optional: libnotify sends desktop notification
```

### Configuration / Build Flow

```
flake.nix
    |
    +--> voxtype input pinned in flake.lock
    |
    v
nixos-rebuild switch
    |
    +--> nixosModules.default evaluated
    |       programs.ydotool.enable (already true)
    |       voxtype package in systemPackages
    |
    +--> homeManagerModules.default evaluated
            programs.voxtype.settings --> ~/.config/voxtype/config.toml
            programs.voxtype.model.name --> model downloaded to store
            programs.voxtype.service.enable --> systemd user service unit
```

### Status Widget Flow

```
waybar (running)
    |
    v
custom/stt exec: ~/.config/waybar/scripts/stt-status.sh
    |
    v
script queries voxtype daemon state
(mechanism TBD: socket file, process presence, or voxtype status subcommand)
    |
    v
waybar displays recording indicator in status bar
```

### Key Data Flows Summary

1. **Config generation:** `programs.voxtype.settings` Nix attrset -> merged with defaults -> written to `~/.config/voxtype/config.toml` by home-manager
2. **Model provisioning:** `programs.voxtype.model.name` -> HuggingFace download -> path injected into config at build time (no runtime download)
3. **Text injection:** voxtype daemon -> wtype (Wayland) for "type" mode; wl-copy for clipboard mode
4. **Hotkey control:** niri binds -> `voxtype record start`/`stop` process calls -> daemon IPC

## Anti-Patterns

### Anti-Pattern 1: Keeping waystt alongside voxtype

**What people do:** Add voxtype while leaving the existing `waystt` package, overlay, and custom package definition in place.

**Why it's wrong:** Causes two competing STT daemons, duplicate keybindings, and confusion about which tool is active. The `packages/waystt/` overlay entry also adds unnecessary build complexity.

**Do this instead:** Remove `waystt` from `environment.systemPackages` in `common/configuration.nix`, remove the overlay entry in `flake.nix`, and delete `packages/waystt/`. Migrate the keybindings and waybar script in the same change.

### Anti-Pattern 2: System-level package only (skipping homeManagerModule)

**What people do:** Add `voxtype.nixosModules.default` only, or just add the package to `environment.systemPackages`, without importing `homeManagerModules.default`.

**Why it's wrong:** The systemd user service, declarative TOML config generation, and model management all live in the home-manager module. Without it, voxtype is installed but not running as a daemon — you'd have to start it manually every session.

**Do this instead:** Always import both modules. The nixos module handles system-level concerns (ydotool socket, input group); the home-manager module handles user-level concerns (daemon, config, model).

### Anti-Pattern 3: Hardcoding the vulkan package in common home.nix

**What people do:** Set `programs.voxtype.package = inputs.voxtype.packages.x86_64-linux.vulkan` in common home.nix to get GPU acceleration everywhere.

**Why it's wrong:** mischief (Intel HD 520) has no Vulkan-capable GPU. The vulkan build will either fail to build or crash at runtime on that host. Vulkan on Intel iGPUs also provides minimal speedup over CPU for Whisper inference.

**Do this instead:** Default to `packages.default` (CPU) in common; override to `packages.vulkan` only in intrepid and vigilant host-specific home.nix.

### Anti-Pattern 4: Using toggle-script approach instead of record start/stop

**What people do:** Carry over the existing `stt-toggle.sh` toggle script approach when migrating from waystt to voxtype.

**Why it's wrong:** voxtype is designed around `record start` / `record stop` — it has a persistent daemon and explicit start/stop IPC. Toggle scripts that kill/relaunch the daemon introduce latency and can leave the daemon in a broken state if the toggle fires out of sequence.

**Do this instead:** Use niri's press/release bind pair to call `voxtype record start` on keydown and `voxtype record stop` on keyup. This is the canonical push-to-talk pattern.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| PipeWire | voxtype reads mic directly via PipeWire API | Already enabled in `common/configuration.nix`. No extra config needed. |
| ydotool daemon | voxtype uses ydotool socket for text injection fallback | `programs.ydotool.enable = true` already present. The nixosModule may re-assert this. |
| wtype | Primary Wayland text injection method (injected into PATH by wrapped package) | Included in voxtype's wrapped package — no separate install needed. |
| HuggingFace | Model download at build time when `model.name` is set | Requires internet at `nixos-rebuild` time for first build. Model is then in the Nix store. |
| libnotify / mako | Desktop notifications for recording start/stop | `libnotify` already in common home.nix; mako running as notification daemon. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| flake.nix ↔ voxtype flake | Nix flake protocol (inputs/outputs) | `inputs` passed via `specialArgs` and `extraSpecialArgs` in mkHost — existing pattern, no changes to mkHost needed |
| nixosModule ↔ homeManagerModule | Conventional split: system vs user scope | nixosModule sets system packages + ydotool; homeManagerModule sets user service + config. Import both. |
| niri ↔ voxtype daemon | Process spawn (`voxtype record start/stop`) | Niri spawns short-lived processes; daemon already running via systemd user service |
| voxtype daemon ↔ waybar | Status query (mechanism TBD) | Current `stt-status.sh` script polls waystt state; needs update for voxtype's state API. Verify voxtype has a `status` subcommand or socket. |
| common home.nix ↔ host home.nix | Nix module system override | `programs.voxtype.package` set in common, overridden per-host using standard module merging (no `lib.mkForce` needed for package attribute) |

## Build Order Implications

The component dependency graph determines phase ordering:

```
1. flake.nix inputs
       |
       v
2. nixosModules import (configuration.nix)
   -- depends on: flake input wired in
   -- provides: system package, ydotool integration
       |
       v
3. homeManagerModules import (home.nix)
   -- depends on: flake input, nixosModule for ydotool socket
   -- provides: daemon, config.toml, model
       |
       v
4. Per-host package variant (intrepid/vigilant home.nix)
   -- depends on: homeManagerModule in common
       |
       v
5. Compositor keybindings (config/niri/config.kdl)
   -- depends on: daemon running (step 3)
   -- can be edited independently, but useless without daemon
       |
       v
6. Waybar status widget (config/waybar/)
   -- depends on: daemon running + knowing voxtype state API
   -- lowest priority; cosmetic, not functional
```

**Recommended build order for implementation phases:**

1. Wire flake input + nixosModule + homeManagerModule with CPU default — get the daemon running on all hosts
2. Verify basic push-to-talk works on one host (mischief, CPU, lowest risk)
3. Update niri keybindings (replaces waystt bindings)
4. Add per-host Vulkan overrides for intrepid and vigilant
5. Update waybar status script for voxtype state API
6. Remove waystt package, overlay, and old toggle scripts

## Sources

- voxtype flake.nix outputs (MEDIUM confidence — via WebFetch from github.com/peteonrails/voxtype): packages expose `default`, `vulkan`, `rocm`, `onnx` variants; `homeManagerModules.default` and `nixosModules.default`
- voxtype home-manager-module.nix (MEDIUM confidence — via WebFetch): `programs.voxtype.{enable, engine, package, model, settings, service.enable}` options confirmed
- voxtype nixos-module.nix (MEDIUM confidence — via WebFetch): system-level package + ydotool integration; no user service (that's home-manager's job)
- voxtype README push-to-talk section (MEDIUM confidence — via WebFetch): `voxtype record start/stop` command interface; `hotkey.enabled = false` to defer to compositor
- voxtype news page (MEDIUM confidence — voxtype.io/news): v0.6.3 NixOS improvements confirmed; parakeet-rs ONNX runtime compatibility with NixOS 25.05
- Existing repo direct inspection (HIGH confidence): `programs.ydotool.enable` already set; `users.extraGroups` includes `input`; waystt currently installed via overlay; niri and waybar configs with existing STT bindings; per-host Vulkan GPU setup pattern already established

---
*Architecture research for: voxtype speech-to-text integration into NixOS flake multi-host dotfiles*
*Researched: 2026-03-20*
