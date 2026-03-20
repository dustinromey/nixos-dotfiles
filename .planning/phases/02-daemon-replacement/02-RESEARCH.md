# Phase 2: Daemon + Replacement - Research

**Researched:** 2026-03-20
**Domain:** voxtype Home Manager module, systemd user services, evdev hotkey config, waystt removal
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STT-01 | Voxtype daemon running as systemd user service on all three hosts | `programs.voxtype.service.enable = true` in HM module creates the service; `wantedBy = ["graphical-session.target"]` targets all three hosts identically via common home.nix |
| STT-02 | Whisper base.en model configured for transcription | `programs.voxtype.model.name = "base.en"` triggers HuggingFace download; alternatively `settings.whisper.model = "base.en"` in the settings TOML block (default.toml already sets `model = "base.en"` in the whisper section) |
| STT-03 | Text injection at cursor working via wtype/ydotool | voxtype wraps wtype, dotool, ydotool, wl-clipboard, xclip at build time; output chain is wtype→eitype→dotool→ydotool→clipboard; `settings.output.mode = "type"` selects typing mode |
| STT-04 | Service PATH workaround applied for upstream bug #253 | Bug #253 is open and assigned to milestone 0.6.4 but NOT fixed in the v0.6.4 tag; workaround is `systemd.user.services.voxtype.Service.Environment = ["PATH=/run/current-system/sw/bin"]` in home.nix |
| PTT-01 | Push-to-talk working via voxtype's built-in evdev hotkey mode | `settings.hotkey.enabled = true` + `settings.hotkey.mode = "push_to_talk"` activates evdev detection; user must be in `input` group (already in common/configuration.nix) |
| PTT-02 | Hotkey configured as Alt_R + Menu combo | `settings.hotkey.key = "RIGHTALT"` with `settings.hotkey.modifiers = ["MENU"]` — or inverted (MENU as key, RIGHTALT as modifier); see Open Questions |
| PTT-03 | Voxtype hotkey uses evdev (not compositor bindings, since Niri lacks key-release) | `settings.hotkey.enabled = true` bypasses Niri; evdev works at kernel level regardless of compositor key-release support |
| REM-01 | Waystt overlay removed from flake.nix | Already done in Phase 1; flake.nix confirmed clean |
| REM-02 | Waystt package directory (packages/waystt/) removed | Already done in Phase 1; `packages/` directory is empty |
| REM-03 | Waystt-related Niri keybindings removed from config | Two binds in config/niri/config.kdl lines 80-82: `Mod+R` and `Mod+Shift+R` calling stt-toggle.sh; delete both |
| REM-04 | Waystt toggle/status scripts removed or replaced | `bin/stt-toggle.sh` and `config/waybar/scripts/stt-status.sh` both reference waystt; voxtype daemon handles PTT natively so stt-toggle.sh can be deleted; stt-status.sh needs replacement or deletion |
</phase_requirements>

## Summary

Phase 2 configures the voxtype Home Manager module (already imported in common home.nix from Phase 1) with: the systemd user service enabled, the whisper base.en model, evdev push-to-talk with the Alt_R + Menu hotkey, and the PATH workaround for upstream bug #253. Simultaneously, all waystt artifacts are purged: the two Niri keybindings, the stt-toggle.sh script, and the stt-status.sh waybar script.

The voxtype daemon is self-contained for push-to-talk — once the Home Manager module configures and starts the service, there is no need for an external toggle script. The old waystt model (fire-and-forget process + compositor keybind) is replaced by a persistent daemon + evdev hotkey. This means the waybar `custom/stt` module will also need updating or removal since it was designed to toggle a process, not reflect daemon state.

The key risk in this phase is the hotkey key-name lookup. The prior decision says "Alt_R + Menu" but voxtype's evdev layer uses raw Linux kernel key names (`RIGHTALT`, `MENU`). Whether the physical Menu key on each host reports as `KEY_MENU` or `KEY_COMPOSE` must be verified with `evtest` since keyboards vary. The plan should include a step to run evtest and confirm the key name before finalizing the TOML config.

**Primary recommendation:** Set `programs.voxtype.service.enable = true`, configure `settings.hotkey` with `enabled = true`, `mode = "push_to_talk"`, `key = "MENU"`, `modifiers = ["RIGHTALT"]`; add the PATH environment override; delete stt-toggle.sh and the two Niri keybinds; update or remove the waybar STT module.

## Standard Stack

### Core
| Component | Version/Ref | Purpose | Why Standard |
|-----------|-------------|---------|--------------|
| `inputs.voxtype.homeManagerModules.default` | v0.6.4 | HM module providing `programs.voxtype` options + systemd service | Already imported in common home.nix (Phase 1); this is the official module |
| `programs.voxtype.service.enable` | v0.6.4 HM module | Creates `systemd.user.services.voxtype` unit | Module option; `false` by default, must be set to `true` |
| `programs.voxtype.settings` | v0.6.4 HM module | Writes `~/.config/voxtype/config.toml` via `tomlFormat.generate` | Declarative config, merged with `default.toml` via `lib.recursiveUpdate` |
| `programs.voxtype.model.name` | v0.6.4 HM module | Downloads model from HuggingFace | Module option; separate from settings; sets path for the engine |

### Supporting
| Component | Version/Ref | Purpose | When to Use |
|-----------|-------------|---------|-------------|
| `systemd.user.services.voxtype` override | HM `systemd.user.services` | Apply PATH workaround for bug #253 | Required until upstream fixes #253 |
| `evtest` | system package | Discover actual evdev key names for physical keys | Run once per host keyboard to confirm `MENU` key name |
| `wtype` (bundled) | wrapped in voxtype pkg | Primary text injection on Wayland | Automatic — voxtype falls through chain |
| `dotool` (bundled) | wrapped in voxtype pkg | Secondary text injection (daemon-free) | Automatic fallback |
| `ydotool` (bundled) | wrapped in voxtype pkg | Tertiary text injection via daemon | Already configured in common config; automatic fallback |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| evdev hotkey (`settings.hotkey.enabled = true`) | Compositor keybind calling `voxtype record start/stop` | Niri has no key-release event for binds — compositor approach is not viable for push-to-talk; evdev is required |
| `programs.voxtype.model.name = "base.en"` | `settings.whisper.model = "base.en"` | Both work; `model.name` triggers HuggingFace download and auto-resolves path; `settings.whisper.model` uses the name directly in config.toml and relies on voxtype to resolve it at runtime — the module assertion prevents using both simultaneously |

## Architecture Patterns

### Home Manager Module Configuration Pattern

The module is already imported in `hosts/common/home.nix`. All configuration goes in that file under `programs.voxtype`:

```nix
# Source: voxtype v0.6.4 nix/home-manager-module.nix
programs.voxtype = {
  enable = true;
  package = inputs.voxtype.packages.${pkgs.system}.default;  # CPU; override per-host in Phase 3

  service.enable = true;

  model.name = "base.en";  # Downloads from HuggingFace on first activation

  settings = {
    hotkey = {
      enabled = true;
      key = "MENU";           # Linux evdev name for the Menu/App key
      modifiers = [ "RIGHTALT" ];
      mode = "push_to_talk";  # Hold to record, release to transcribe
    };
    output = {
      mode = "type";
      fallback_to_clipboard = true;
    };
    whisper = {
      language = "en";
    };
  };
};
```

### PATH Workaround Pattern

The systemd user service needs `/run/current-system/sw/bin` on its PATH so that wtype/ydotool/dotool are found at runtime. Override the service after the module defines it:

```nix
# Source: voxtype GitHub issue #253 workaround
# Place in hosts/common/home.nix alongside programs.voxtype config
systemd.user.services.voxtype = {
  Service = {
    Environment = [ "PATH=/run/current-system/sw/bin:${inputs.voxtype.packages.${pkgs.system}.default}/bin" ];
  };
};
```

Note: Using `lib.mkForce` is NOT needed here — the HM module does not set `Environment` at all, so this is an additive merge. The voxtype package bin dir is included to ensure the daemon binary itself is on PATH.

### Niri Keybinding Removal Pattern

Remove both STT lines from `config/niri/config.kdl`. Lines 80-82 are the only waystt references in the file:

```
// Speech to Text (waystt)             ← DELETE this comment line
Mod+R hotkey-overlay-title="STT (type)" { spawn "bash" "-c" "YDOTOOL_SOCKET=/run/user/1000/.ydotool_socket ~/.local/bin/stt-toggle.sh type"; }   ← DELETE
Mod+Shift+R hotkey-overlay-title="STT (clipboard)" { spawn "bash" "-c" "~/.local/bin/stt-toggle.sh clipboard"; }   ← DELETE
```

No replacement Niri keybinding is needed — voxtype handles push-to-talk via evdev internally.

### Script Removal

- **`bin/stt-toggle.sh`**: Delete entirely. Voxtype daemon handles recording lifecycle; no external toggle needed.
- **`config/waybar/scripts/stt-status.sh`**: Delete or replace. The script polls `pgrep -x waystt` which will never match. The waybar `custom/stt` module referencing it should also be removed from `config/waybar/config.jsonc`.

### Anti-Patterns to Avoid

- **Keeping stt-toggle.sh as a voxtype wrapper**: The voxtype daemon uses evdev, not signals. The old waystt pattern (SIGUSR1 to transcribe) does not apply to voxtype. Any wrapper would need to call `voxtype record start/stop` which is redundant when evdev is active.
- **Setting `settings.hotkey.enabled = false` and using compositor keybinds**: Niri does not emit key-release events for keybinds, so `voxtype record stop` would never fire. Push-to-talk requires evdev.
- **Using `model.name` and `settings.whisper.model` simultaneously**: The module has an assertion that prevents this — choose one. Use `model.name = "base.en"` for HuggingFace auto-download.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| evdev key capture for PTT | Custom evdev listener script | `settings.hotkey.enabled = true` in voxtype | voxtype has full push-to-talk evdev support built-in; custom listeners duplicate logic and miss release detection |
| Text injection | Custom wtype/ydotool wrapper | voxtype's built-in output chain (wtype→dotool→ydotool→clipboard) | voxtype wraps all deps at build time; the chain handles fallback automatically |
| Whisper model management | Script to download .bin file | `programs.voxtype.model.name = "base.en"` | Module handles HuggingFace download, path resolution, and config injection |
| Systemd service definition | `systemd.user.services.voxtype` from scratch | `programs.voxtype.service.enable = true` | Module already defines the correct Unit/Install targets; only override `Environment` for the PATH bug |
| Toggle script | New stt-toggle.sh calling `voxtype record start/stop` | Nothing — evdev handles it | A toggle script is only needed when compositor keybinds are used; evdev eliminates this entirely |

**Key insight:** Voxtype's daemon + evdev pattern replaces the entire old model (process-per-recording + external signal). The planner should not add any task that recreates toggle/status script infrastructure.

## Common Pitfalls

### Pitfall 1: Wrong evdev key name for Menu key
**What goes wrong:** Config uses `MENU` but the physical key reports as `COMPOSE` (or vice versa), and push-to-talk never activates.
**Why it happens:** The physical "Menu/App" key (right of right-Alt on many keyboards) can report as `KEY_MENU` or `KEY_COMPOSE` depending on the keyboard firmware and kernel driver. The three hosts (ThinkPad X270, desktop, Surface Laptop 4) likely have different keyboards with different behaviors.
**How to avoid:** Run `sudo evtest` on each host's keyboard, press the target key, and observe whether it reports `KEY_MENU` or `KEY_COMPOSE`. The voxtype config uses the part after `KEY_` (i.e., `MENU` or `COMPOSE`). Surface Laptop 4 may not have a Menu key at all — may need to pick a different key for `mischief`.
**Warning signs:** `systemctl --user status voxtype` shows running but holding Alt_R + Menu produces no recording start notification.

### Pitfall 2: Bug #253 PATH issue causing "All output methods failed"
**What goes wrong:** The voxtype daemon starts successfully but transcription fails silently or logs "All output methods failed. Ensure wtype, dotool, ydotool, wl-copy, or xclip is available."
**Why it happens:** Systemd user services inherit a minimal environment. Even though the voxtype package wraps all deps, the service cannot find them because `PATH` inside systemd user service context doesn't include `/run/current-system/sw/bin`. Bug #253 is open and unresolved in v0.6.4.
**How to avoid:** Apply the PATH workaround: `systemd.user.services.voxtype.Service.Environment = ["PATH=/run/current-system/sw/bin:..."]`.
**Warning signs:** `journalctl --user -u voxtype` shows "All output methods failed" or similar errors after a recording completes.

### Pitfall 3: `service.enable` defaults to false
**What goes wrong:** `programs.voxtype.enable = true` is set but no service runs; `systemctl --user status voxtype` says "Unit voxtype.service could not be found."
**Why it happens:** The HM module separates package installation (`programs.voxtype.enable`) from service creation (`programs.voxtype.service.enable`). Both must be explicitly enabled. The nixosModule from Phase 1 only handles the system package; the HM module's `service.enable` is what creates the user service.
**How to avoid:** Set both `programs.voxtype.enable = true` AND `programs.voxtype.service.enable = true` in the HM module config.
**Warning signs:** `systemctl --user list-units | grep voxtype` returns nothing after `home-manager switch`.

### Pitfall 4: Waybar stt-status.sh module still running after waystt removal
**What goes wrong:** Waybar shows the STT module but it always shows "inactive" state (polling `pgrep -x waystt` which never matches).
**Why it happens:** `config/waybar/config.jsonc` references `custom/stt` which exec's `stt-status.sh` on a 1-second interval. The script was written for waystt and has no voxtype awareness.
**How to avoid:** Remove the `"custom/stt"` entry from `modules-right` in waybar config AND the `"custom/stt"` module definition. If a voxtype status indicator is desired, that is Phase 3+ work.
**Warning signs:** Waybar shows an STT icon that never changes state.

### Pitfall 5: `model.name` conflict with `settings.whisper.model`
**What goes wrong:** Setting both `programs.voxtype.model.name = "base.en"` and `settings.whisper.model = "base.en"` causes a module assertion failure during `nixos-rebuild`.
**Why it happens:** The HM module has an assertion: `assert !(cfg.model.name != null && cfg.settings ? whisper && cfg.settings.whisper ? model)`.
**How to avoid:** Use only `programs.voxtype.model.name = "base.en"`. Remove any `settings.whisper.model` override.
**Warning signs:** `nixos-rebuild switch` fails with an assertion error mentioning `model.name` and `settings.whisper.model`.

### Pitfall 6: Whisper model download requires internet at first activation
**What goes wrong:** `home-manager switch` succeeds but the first `systemctl --user start voxtype` hangs or fails because the model file doesn't exist yet.
**Why it happens:** `programs.voxtype.model.name` triggers a HuggingFace model download at service first-start, not at build time. If the host has no internet or the download is slow, the daemon may fail to start.
**How to avoid:** Ensure internet access during first activation. The model is cached in `~/.local/share/voxtype/` after first download.
**Warning signs:** `journalctl --user -u voxtype` shows model download errors or "model file not found".

## Code Examples

### Complete programs.voxtype HM config (common home.nix)
```nix
# Source: voxtype v0.6.4 home-manager-module.nix options + bug #253 workaround
programs.voxtype = {
  enable = true;
  package = inputs.voxtype.packages.${pkgs.system}.default;

  service.enable = true;

  model.name = "base.en";

  settings = {
    hotkey = {
      enabled = true;
      key = "MENU";
      modifiers = [ "RIGHTALT" ];
      mode = "push_to_talk";
    };
    output = {
      mode = "type";
      fallback_to_clipboard = true;
    };
    whisper = {
      language = "en";
    };
  };
};

# Bug #253 workaround: systemd user service lacks PATH for output tools
systemd.user.services.voxtype = {
  Service = {
    Environment = [ "PATH=/run/current-system/sw/bin" ];
  };
};
```

### Niri config.kdl: lines to remove
```
// Speech to Text (waystt)
Mod+R hotkey-overlay-title="STT (type)" { spawn "bash" "-c" "YDOTOOL_SOCKET=/run/user/1000/.ydotool_socket ~/.local/bin/stt-toggle.sh type"; }
Mod+Shift+R hotkey-overlay-title="STT (clipboard)" { spawn "bash" "-c" "~/.local/bin/stt-toggle.sh clipboard"; }
```

### Waybar config.jsonc: entries to remove
```json
// Remove from modules-right array:
"custom/stt"

// Remove the module definition block:
"custom/stt": {
    "exec": "~/.config/waybar/scripts/stt-status.sh",
    "return-type": "json",
    "interval": 1,
    "on-click": "~/.local/bin/stt-toggle.sh",
    "tooltip": true
}
```

### Verify service is running (post-deployment check)
```bash
# After home-manager switch:
systemctl --user status voxtype
journalctl --user -u voxtype -n 30

# Verify hotkey registration (check voxtype daemon output):
journalctl --user -u voxtype | grep -i "hotkey\|evdev\|listening"
```

### Verify evdev key names (run on each host before finalizing config)
```bash
sudo evtest
# Select keyboard device, press Menu key
# Look for: Event: type 1 (EV_KEY), code 127 (KEY_COMPOSE) or 139 (KEY_MENU)
# Press RIGHTALT key
# Look for: Event: type 1 (EV_KEY), code 100 (KEY_RIGHTALT)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| waystt: fire-and-forget process per recording | voxtype: persistent daemon with evdev PTT | Phase 2 | No external toggle script needed; compositor doesn't need key-release event |
| stt-toggle.sh: SIGUSR1 to transcribe | voxtype daemon handles recording start/stop internally | Phase 2 | stt-toggle.sh is deleted entirely |
| Niri keybinds: `Mod+R` / `Mod+Shift+R` spawning scripts | voxtype evdev hotkey: `Alt_R + MENU` at kernel level | Phase 2 | Works even when Niri window is not focused; no compositor involvement |
| wtype called from shell script | voxtype wraps wtype/dotool/ydotool at build time | v0.6.3+ | Deps always available in voxtype's environment; PATH bug workaround needed |

**Deprecated/outdated:**
- `bin/stt-toggle.sh`: Entire script is waystt-specific; no voxtype analog needed with evdev mode
- `config/waybar/scripts/stt-status.sh`: Polls `pgrep -x waystt`; voxtype daemon has no equivalent polling interface in v0.6.4

## Open Questions

1. **Correct evdev key name for the Menu key on each host**
   - What we know: The physical right-side "Application/Menu" key can report as `KEY_MENU` (keycode 139) or `KEY_COMPOSE` (keycode 127) depending on keyboard
   - What's unclear: Which name each of the three keyboards (ThinkPad X270, desktop RK S70, Surface Laptop 4) reports; Surface Laptop 4 may not have a Menu key at all
   - Recommendation: The plan should include a verification step: run `sudo evtest` on each host and confirm the key name before or after initial deployment. Use `MENU` as the default in the config (most common) and note in the plan that hosts may need per-host overrides. Surface (vigilant) may need a different key entirely.

2. **Waybar STT module: remove vs. replace**
   - What we know: `config/waybar/config.jsonc` has a `custom/stt` module that calls `stt-status.sh` every second and `stt-toggle.sh` on click — both are waystt-specific and must be removed
   - What's unclear: Whether a voxtype status module is desired (voxtype daemon could potentially emit status via a socket or notification)
   - Recommendation: Remove entirely in Phase 2 (matches REM-04 scope). A voxtype-aware waybar module is Phase 3+ scope. The plan should remove `"custom/stt"` from `modules-right` and delete the module definition block.

3. **Bug #253 PATH workaround scope**
   - What we know: The workaround `Environment = ["PATH=/run/current-system/sw/bin"]` is confirmed effective per issue reporter; bug is open in v0.6.4
   - What's unclear: Whether `/run/current-system/sw/bin` alone is sufficient or whether the voxtype package bin dir also needs to be included
   - Recommendation: Include both paths to be safe: `"PATH=/run/current-system/sw/bin:${inputs.voxtype.packages.${pkgs.system}.default}/bin"`. The daemon binary is already wrapped but including it explicitly prevents issues if the daemon itself needs to exec sub-commands.

## Sources

### Primary (HIGH confidence)
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/nix/home-manager-module.nix` — module options: `service.enable` (default false), `model.name`, `settings` (tomlFormat), `ExecStart`, absence of Environment lines
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/config/default.toml` — confirmed `hotkey.enabled = false` as default, `hotkey.key = "SCROLLLOCK"`, `hotkey.modifiers = []`, `whisper.model = "base.en"`, `output.mode = "type"`
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/docs/CONFIGURATION.md` — hotkey options: `key`, `modifiers` (array), `mode` ("push_to_talk"/"toggle"), `enabled`; valid modifiers list includes `RIGHTALT`; `cancel_key` option
- `/home/dustin/nixos-dotfiles/hosts/common/home.nix` — confirmed `inputs.voxtype.homeManagerModules.default` already imported; `programs.voxtype.enable` not yet set in HM module
- `/home/dustin/nixos-dotfiles/hosts/common/configuration.nix` — `programs.voxtype.enable = lib.mkDefault true` and `.package` set (NixOS module only); user already in `input` group
- `/home/dustin/nixos-dotfiles/config/niri/config.kdl` lines 80-82 — exact waystt keybindings to remove
- `/home/dustin/nixos-dotfiles/bin/stt-toggle.sh` — confirmed waystt-specific (SIGUSR1 pattern, `pgrep -x waystt`); not adaptable to voxtype
- `/home/dustin/nixos-dotfiles/config/waybar/scripts/stt-status.sh` — confirmed waystt-specific (`pgrep -x waystt`)
- `/home/dustin/nixos-dotfiles/config/waybar/config.jsonc` — `custom/stt` module at line 92-96 referencing stt-toggle.sh and stt-status.sh

### Secondary (MEDIUM confidence)
- `https://github.com/peteonrails/voxtype/issues/253` — bug confirmed open, assigned to milestone 0.6.4 but NOT closed; PATH workaround `Environment = ["PATH=/run/current-system/sw/bin"]` confirmed effective per reporter
- `https://github.com/peteonrails/voxtype/commits/v0.6.4/nix/home-manager-module.nix` — commit history shows no PATH fix merged; v0.6.4 NixOS change was only settings merge behavior
- `https://voxtype.io/news/` — v0.6.3 "Fix NixOS systemd service path issue" mentioned but specific fix described was settings merge, not service Environment

### Tertiary (LOW confidence)
- WebSearch: evdev key names for Menu key — `KEY_MENU` (139) vs `KEY_COMPOSE` (127) distinction; keyboard-specific and needs per-host verification with `evtest`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — read actual module source at v0.6.4 tag; all option names verified
- Architecture: HIGH — module options confirmed; PATH workaround confirmed from issue tracker; file locations confirmed from repo inspection
- Pitfalls: HIGH for bugs #253 (verified from issue tracker), service.enable default, and model assertion; MEDIUM for evdev key names (needs per-host verification)

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (pinned to v0.6.4 tag; 30 days)
