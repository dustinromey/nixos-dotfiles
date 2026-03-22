# Phase 3: GPU Acceleration + Waybar - Research

**Researched:** 2026-03-22
**Domain:** NixOS multi-host package variants (voxtype Vulkan), Waybar custom module integration
**Confidence:** HIGH

## Summary

Phase 3 has two distinct tracks: (1) switching intrepid and vigilant from the default CPU voxtype package to the `vulkan` package variant, and (2) adding a Waybar module that displays live voxtype recording state. Both tracks are straightforward given the existing infrastructure — AMD GPU driver support (amdvlk, vulkan-loader, AMD_VULKAN_ICD=RADV) is already present in both AMD host configurations, and the voxtype flake already exposes a `packages.${system}.vulkan` output.

The GPU switch is a one-line change per host: set `programs.voxtype.package` to `inputs.voxtype.packages.${pkgs.system}.vulkan` in each AMD host's `home.nix`. Because `lib.mkDefault` wraps the common config's CPU package, any direct assignment in a host-specific file overrides it without conflict. The critical pitfall is that the PATH workaround in common `home.nix` currently hardcodes `inputs.voxtype.packages.${pkgs.system}.default` — this must be updated to `config.programs.voxtype.package` so that Vulkan hosts get the correct store path in their systemd service environment.

The Waybar integration uses `voxtype status --follow --format json` as a long-running exec script producing JSON output Waybar natively understands. This approach is documented in voxtype's official WAYBAR.md. The existing `style.css` already defines `#custom-stt` CSS rules, but uses class names (`ready`, `inactive`) that don't match voxtype's actual output (`idle`, `stopped`). Both the CSS classes and the waybar config.jsonc need to be aligned. Waybar's systemd service on NixOS has a restricted PATH — adding voxtype to `systemd.user.services.waybar.path` resolves this without needing store-path hacks in config.jsonc.

**Primary recommendation:** Override `programs.voxtype.package` to vulkan variant in intrepid/vigilant home.nix; fix PATH workaround to use `config.programs.voxtype.package`; add `"custom/stt"` Waybar module using `voxtype status --follow --format json`; update CSS classes to match voxtype's actual state names.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GPU-01 | Vulkan package variant used on intrepid (AMD desktop) | `inputs.voxtype.packages.${pkgs.system}.vulkan` exists as confirmed flake output; intrepid already has amdvlk + vulkan-loader |
| GPU-02 | Vulkan package variant used on vigilant (AMD Surface Laptop) | Same package output; vigilant already has amdvlk + vulkan-loader + AMD_VULKAN_ICD=RADV |
| GPU-03 | CPU-only (default) package variant used on mischief (Intel) | Default in common home.nix with lib.mkDefault; mischief has no AMD GPU config so no override needed |
| BAR-01 | Waybar STT status script updated to query voxtype state | `voxtype status --follow --format json` is the official mechanism per WAYBAR.md; no separate script needed |
| BAR-02 | Waybar module shows recording/idle status for voxtype | Custom module `"custom/stt"` in config.jsonc + CSS in style.css; state classes: idle, recording, transcribing, stopped |
</phase_requirements>

## Standard Stack

### Core Components

| Component | Version/Source | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| `inputs.voxtype.packages.${pkgs.system}.vulkan` | v0.6.4 tag | Vulkan-accelerated voxtype binary | Official flake output; pre-built with Vulkan support |
| `inputs.voxtype.packages.${pkgs.system}.default` | v0.6.4 tag | CPU-only voxtype binary | Already in use; lib.mkDefault allows per-host override |
| `amdvlk` + `vulkan-loader` | nixpkgs 25.05 | AMD Vulkan ICD + loader | Already installed on intrepid/vigilant |
| `AMD_VULKAN_ICD = "RADV"` | system environment | Forces RADV (Mesa) over amdvlk | Already set on both AMD hosts |
| Waybar custom module | waybar (in home.packages) | Displays voxtype state in status bar | Waybar's native custom module system |

### Voxtype Package Variants (confirmed from flake.nix at v0.6.4)

| Attribute | Backend | Use |
|-----------|---------|-----|
| `packages.${system}.default` | CPU (whisper.cpp) | mischief (Intel HD 520) |
| `packages.${system}.vulkan` | Vulkan GPU | intrepid, vigilant (AMD) |
| `packages.${system}.rocm` | ROCm AMD GPU | Not used (more complex) |
| `packages.${system}.onnx` | ONNX CPU | Not used |
| `packages.${system}.onnx-rocm` | ONNX + AMD GPU | Not used |

### Waybar Module Fields (from official waybar-custom man page)

| Field | Value | Purpose |
|-------|-------|---------|
| `exec` | `voxtype status --follow --format json` | Long-running process outputting JSON on state change |
| `return-type` | `"json"` | Tells Waybar to parse JSON output |
| `format` | `"{}"` or `"{icon}"` | Display format |
| `tooltip` | `true` | Show tooltip from JSON `tooltip` field |
| `format-icons` | `{"idle": ..., "recording": ...}` | Map `alt` field to icons |

## Architecture Patterns

### Pattern 1: Per-Host Package Override with lib.mkDefault

**What:** Common home.nix sets package with `lib.mkDefault`; host-specific home.nix assigns directly to override.

**When to use:** When AMD hosts need Vulkan and Intel host needs CPU-only.

**Example:**
```nix
# hosts/common/home.nix — sets low-priority default
programs.voxtype = {
  enable = true;
  package = lib.mkDefault inputs.voxtype.packages.${pkgs.system}.default;
  # ...
};

# The PATH workaround MUST reference config.programs.voxtype.package, not the literal default:
systemd.user.services.voxtype = {
  Service = {
    Environment = [
      "PATH=/run/current-system/sw/bin:${config.programs.voxtype.package}/bin"
    ];
  };
};
```

```nix
# hosts/intrepid/home.nix — direct assignment overrides lib.mkDefault
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];

  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
```

```nix
# hosts/vigilant/home.nix — same pattern
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];

  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
```

```nix
# hosts/mischief/home.nix — no override needed; lib.mkDefault CPU package applies
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];
  # No programs.voxtype.package override — CPU default applies
}
```

### Pattern 2: Waybar Custom Module with Long-Running exec

**What:** `voxtype status --follow --format json` runs continuously as a child process of Waybar, writing JSON on each state transition. No polling interval needed.

**When to use:** When a tool provides a --follow mode that streams state changes (preferred over interval polling for real-time UI).

**Example (config.jsonc):**
```jsonc
"custom/stt": {
  "exec": "voxtype status --follow --format json",
  "return-type": "json",
  "format": "{icon}",
  "format-icons": {
    "idle":         "",
    "recording":    "",
    "transcribing": "",
    "stopped":      ""
  },
  "tooltip": true
}
```

Add `"custom/stt"` to `modules-right` in config.jsonc.

### Pattern 3: Waybar PATH via systemd.user.services.waybar.path

**What:** On NixOS, Waybar's systemd user service has a restricted PATH. Custom module exec commands can't find tools by name unless the PATH is extended.

**When to use:** Any time a Waybar custom module runs a command that isn't a full Nix store path.

**Example:**
```nix
# In home.nix — extend Waybar's service PATH to include voxtype
systemd.user.services.waybar = {
  path = [ config.programs.voxtype.package ];
};
```

This adds `${voxtype-package}/bin` to PATH so `voxtype` resolves in the exec command.

### Pattern 4: Verifying Vulkan Backend is Active

**What:** After deploying the Vulkan package, confirm it actually uses GPU acceleration.

**Mechanisms:**
1. `voxtype status --format json --extended` — JSON output includes `backend` field showing "Vulkan" or "CPU (AVX2)"
2. `journalctl --user -u voxtype -n 50` — startup logs show backend initialization
3. `voxtype setup gpu` — shows current backend status (note: on NixOS this is read-only; the package variant determines backend, not runtime switching)

**Important NixOS distinction:** The `voxtype setup gpu --enable` command works by symlinking binaries at runtime — this does NOT apply to NixOS deployments. The package variant selected in Nix (`packages.${system}.vulkan`) IS the backend. `voxtype status --format json --extended` is the correct verification method.

### Recommended File Changes

```
hosts/
├── common/home.nix          # Fix PATH workaround to use config.programs.voxtype.package
├── intrepid/home.nix        # Add programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan
└── vigilant/home.nix        # Add programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan

config/waybar/
├── config.jsonc             # Add "custom/stt" module + add to modules-right
└── style.css                # Update #custom-stt state classes to match voxtype output
```

### Anti-Patterns to Avoid

- **Hardcoding the CPU package path in PATH workaround:** `${inputs.voxtype.packages.${pkgs.system}.default}/bin` will point to the CPU binary even on Vulkan hosts. Use `${config.programs.voxtype.package}/bin` instead.
- **Using `voxtype setup gpu --enable` on NixOS:** This runtime binary-symlinking approach conflicts with Nix's immutable store. The package variant selection IS the GPU configuration on NixOS.
- **Using interval polling instead of --follow:** `"interval": 1` with `voxtype status --format json` introduces 1-second delay in recording indicator. `--follow` streams changes immediately.
- **Using wrong CSS class names:** voxtype outputs `idle`/`recording`/`transcribing`/`stopped` as `class` and `alt` fields. The existing CSS uses `ready`/`inactive` — these won't match without correction.
- **Naming module "custom/voxtype" when CSS expects "custom/stt":** The existing `style.css` uses `#custom-stt` selector, so the config key must be `"custom/stt"`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recording state detection | Custom inotify watcher on state file | `voxtype status --follow --format json` | Official mechanism; handles all state transitions |
| GPU backend selection | Custom wrapper script or overlay | `inputs.voxtype.packages.${pkgs.system}.vulkan` | Pre-built official variant; correct linkage |
| Waybar PATH resolution | Store paths in config.jsonc exec fields | `systemd.user.services.waybar.path` | Cleaner; survives package updates |
| Icon themes | Custom emoji in config.jsonc | `format-icons` in Waybar config | Natively supported; CSS-styleable |

**Key insight:** voxtype explicitly designed its status output for Waybar integration with JSON output matching Waybar's custom module protocol exactly.

## Common Pitfalls

### Pitfall 1: PATH Workaround Points to Wrong Package

**What goes wrong:** After overriding `programs.voxtype.package` to the Vulkan variant in a host's home.nix, the systemd service PATH still points to the CPU package's `/bin` because common home.nix hardcodes `inputs.voxtype.packages.${pkgs.system}.default`.

**Why it happens:** The PATH environment override in common home.nix was written with a literal package reference, not a reference to the evaluated module option.

**How to avoid:** Change the PATH workaround in common home.nix from:
```nix
"PATH=/run/current-system/sw/bin:${inputs.voxtype.packages.${pkgs.system}.default}/bin"
```
to:
```nix
"PATH=/run/current-system/sw/bin:${config.programs.voxtype.package}/bin"
```

**Warning signs:** `journalctl --user -u voxtype` shows wtype not found even after Vulkan override; `which voxtype` shows CPU binary path from the default package.

### Pitfall 2: CSS Classes Don't Match voxtype Output

**What goes wrong:** Waybar module appears but recording state has no visual change — module stays blue/default colored.

**Why it happens:** The existing `style.css` defines `.ready` and `.inactive` classes. voxtype outputs `idle` and `stopped` as class values. CSS selectors `#custom-stt.idle` and `#custom-stt.stopped` are not defined.

**How to avoid:** Update `style.css` to use voxtype's actual class names:
```css
#custom-stt.idle         { color: @green; }
#custom-stt.recording    { color: @red; animation: pulse 1s ease-in-out infinite; }
#custom-stt.transcribing { color: @yellow; }
#custom-stt.stopped      { color: @inactive; }
```

**Warning signs:** Module appears in Waybar but doesn't change color when push-to-talk is held.

### Pitfall 3: Waybar Can't Find voxtype Binary

**What goes wrong:** Waybar custom module shows nothing or errors — `voxtype` command not found.

**Why it happens:** Waybar's systemd user service has a restricted PATH that doesn't include the user's profile packages.

**How to avoid:** Add to home.nix:
```nix
systemd.user.services.waybar = {
  path = [ config.programs.voxtype.package ];
};
```

**Warning signs:** `journalctl --user -u waybar` shows "exec format error" or "command not found: voxtype".

### Pitfall 4: Expecting `voxtype setup gpu --enable` to Work on NixOS

**What goes wrong:** Running the setup command does nothing persistent, or fails with permission errors on immutable paths.

**Why it happens:** The command works by symlinking binaries on mutable systems. NixOS store is read-only.

**How to avoid:** Don't use `voxtype setup gpu` for enabling Vulkan on NixOS. The package variant selection (`packages.${system}.vulkan`) is the entire GPU configuration. Verify with `voxtype status --format json --extended` instead.

**Warning signs:** User runs `sudo voxtype setup gpu --enable`, rebuild, and expects different behavior than before.

### Pitfall 5: Duplicate Service Configuration Conflict

**What goes wrong:** Nix evaluation error about option defined multiple times for `systemd.user.services.waybar`.

**Why it happens:** If both common home.nix and host home.nix define `systemd.user.services.waybar`, the module system raises a conflict.

**How to avoid:** Define `systemd.user.services.waybar.path` only in common home.nix. It references `config.programs.voxtype.package` which is already the correct variant for each host after override.

## Code Examples

Verified patterns from official sources:

### Vulkan Package Override (hosts/intrepid/home.nix)
```nix
# Source: voxtype flake.nix v0.6.4 — packages.${system}.vulkan confirmed
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];

  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
```

### Fixed PATH Workaround (hosts/common/home.nix)
```nix
# Source: NixOS module system — config.programs.voxtype.package references evaluated option
# Replaces current hardcoded: ${inputs.voxtype.packages.${pkgs.system}.default}/bin
systemd.user.services.voxtype = {
  Service = {
    Environment = [
      "PATH=/run/current-system/sw/bin:${config.programs.voxtype.package}/bin"
    ];
  };
};
```

### Waybar systemd PATH Fix (hosts/common/home.nix)
```nix
# Source: NixOS/nixpkgs issue #425797 — confirmed workaround
systemd.user.services.waybar = {
  path = [ config.programs.voxtype.package ];
};
```

### Waybar Module (config/waybar/config.jsonc)
```jsonc
// Source: voxtype WAYBAR.md (official docs)
"custom/stt": {
  "exec": "voxtype status --follow --format json",
  "return-type": "json",
  "format": "{icon}",
  "format-icons": {
    "idle":         "󰍬",
    "recording":    "󰑊",
    "transcribing": "󰋚",
    "stopped":      "󰍭"
  },
  "tooltip": true
}
```

Add to modules-right array:
```jsonc
"modules-right": ["custom/stt", "pulseaudio", "network", "bluetooth", "battery", "tray"]
```

### CSS for voxtype States (config/waybar/style.css)
```css
/* Source: voxtype WAYBAR.md + existing style.css Tokyo Night palette */
/* Replace existing #custom-stt block with correct class names */
#custom-stt {
  padding: 0 10px;
  color: @blue;
}

#custom-stt.idle {
  color: @green;
}

#custom-stt.recording {
  color: @red;
  animation: pulse 1s ease-in-out infinite;
}

#custom-stt.transcribing {
  color: @yellow;
}

#custom-stt.stopped {
  color: @inactive;
}
```

### Verifying Vulkan Backend Active
```bash
# Source: voxtype USER_MANUAL.md + WAYBAR.md
# Run after nixos-rebuild switch on intrepid/vigilant
voxtype status --format json --extended | jq .backend
# Expected output: "Vulkan" (or similar GPU string)
# On mischief: should show "CPU (AVX2)" or similar
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| All hosts use CPU-only whisper.cpp | AMD hosts use Vulkan backend | Faster transcription on intrepid/vigilant |
| `voxtype setup gpu --enable` runtime switch | Package variant selection in Nix | Reproducible; no runtime mutation needed |
| STT status via polling script | `voxtype status --follow` streaming JSON | Real-time updates without CPU overhead |
| Manual PATH in systemd services | `systemd.user.services.waybar.path` | Cleaner; survives package updates |

**Current state:**
- Style.css has `#custom-stt` block but with wrong class names (`ready`, `inactive` instead of `idle`, `stopped`)
- Waybar config.jsonc has no voxtype/stt module yet
- intrepid and vigilant already have full AMD Vulkan system support (amdvlk, vulkan-loader, RADV)
- PATH workaround in common home.nix uses hardcoded `.default` package — needs fix before Vulkan override works correctly

## Open Questions

1. **Does `voxtype status --follow` exit cleanly when Waybar restarts?**
   - What we know: It's a long-running process; Waybar kills exec processes when stopping
   - What's unclear: Whether there are zombie processes or state file corruption on rapid restart
   - Recommendation: Use `"exec-if": "systemctl --user is-active voxtype"` to prevent exec when daemon is stopped

2. **Does the voxtype module's HM-generated systemd service merge correctly with the manual PATH workaround?**
   - What we know: Nix module system merges `systemd.user.services.voxtype.Service.Environment` lists
   - What's unclear: Whether the voxtype HM module also sets Environment, causing a list merge vs. conflict
   - Recommendation: Verify after applying — if conflict, wrap in `lib.mkForce` or use `systemd.user.services.voxtype.serviceConfig.Environment`

3. **Nerd Font icons availability for voxtype status icons**
   - What we know: Hack Nerd Font is installed (in home.packages); Waybar uses "Hack Nerd Font"
   - What's unclear: Which specific Nerd Font codepoints best represent mic states (might prefer text fallback)
   - Recommendation: Start with text/emoji icons (`""`, `""`, `"..."`, `""`) to avoid codepoint issues; switch to Nerd Font after confirming display

## Sources

### Primary (HIGH confidence)
- `https://github.com/peteonrails/voxtype/blob/v0.6.4/flake.nix` — Package variant names confirmed: `default`, `vulkan`, `rocm`, `onnx`, etc.
- `https://github.com/peteonrails/voxtype/blob/main/docs/WAYBAR.md` — Official Waybar integration guide: exec command, return-type, state names (idle/recording/transcribing/stopped), CSS patterns
- `https://man.archlinux.org/man/extra/waybar/waybar-custom.5.en` — Waybar custom module fields: exec, interval, signal, return-type, format-icons, class
- `/home/dustin/nixos-dotfiles/hosts/intrepid/configuration.nix` — Confirmed: amdvlk, vulkan-loader, AMD_VULKAN_ICD=RADV already present
- `/home/dustin/nixos-dotfiles/hosts/vigilant/configuration.nix` — Confirmed: same AMD Vulkan system config
- `/home/dustin/nixos-dotfiles/hosts/common/home.nix` — Confirmed: PATH workaround hardcodes `.default` package (needs fix)
- `/home/dustin/nixos-dotfiles/config/waybar/style.css` — Confirmed: `#custom-stt` CSS exists with wrong class names
- `/home/dustin/nixos-dotfiles/config/waybar/config.jsonc` — Confirmed: no STT module in config yet

### Secondary (MEDIUM confidence)
- `https://github.com/nixos/nixpkgs/issues/425797` — Waybar systemd PATH issue confirmed; `systemd.user.services.waybar.path` workaround confirmed effective
- `https://github.com/peteonrails/voxtype/blob/v0.6.4/nix/home-manager-module.nix` — HM module has no default for `package` option; ExecStart uses `${cfg.package}/bin/voxtype daemon`
- NixOS module system documentation — `config.programs.voxtype.package` is safe to reference in same home.nix file (lazy evaluation)

### Tertiary (LOW confidence — verify during implementation)
- `voxtype status --extended` backend field format: described as showing "Vulkan" but exact string not confirmed from source code
- Whether `exec-if` guard is necessary for `voxtype status --follow` lifecycle management

## Metadata

**Confidence breakdown:**
- GPU package override pattern: HIGH — lib.mkDefault + host override is standard NixOS pattern; package names confirmed from flake
- PATH workaround fix: HIGH — fix is direct substitution of one package ref for another; lazy eval is standard Nix behavior
- Waybar module integration: HIGH — official WAYBAR.md documents the exact config; state names confirmed
- CSS class alignment: HIGH — discrepancy between existing CSS and voxtype output classes directly confirmed from source inspection
- Vulkan verification method: MEDIUM — `voxtype status --extended` backend field described in docs but exact format not seen in source

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable domain — voxtype is pinned to v0.6.4, Waybar API is stable)
