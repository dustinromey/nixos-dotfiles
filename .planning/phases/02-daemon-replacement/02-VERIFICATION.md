---
phase: 02-daemon-replacement
verified: 2026-03-22T12:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
---

# Phase 2: Daemon Replacement Verification Report

**Phase Goal:** Voxtype daemon runs on all three hosts via systemd user service with evdev push-to-talk; waystt is fully removed with no conflicts
**Verified:** 2026-03-22
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Voxtype systemd user service is defined and will start on graphical-session.target after home-manager switch | VERIFIED | `service.enable = true` in `hosts/common/home.nix:55`; HM module source (`home-manager-module.nix:213,229`) confirms this generates `WantedBy = ["graphical-session.target"]` |
| 2 | Voxtype is configured with base.en model, evdev push-to-talk (MENU + RIGHTALT), and type output mode | VERIFIED | `home.nix:57` `model.name = "base.en"`, `:62-64` `key = "MENU"`, `modifiers = ["RIGHTALT"]`, `mode = "push_to_talk"`, `:67` `mode = "type"` |
| 3 | PATH workaround for bug #253 is applied so wtype/ydotool are found at runtime | VERIFIED | `home.nix:77-83` defines `systemd.user.services.voxtype.Service.Environment` with PATH pointing to voxtype store path; module comment confirms wtype is bundled in the package |
| 4 | No waystt references remain in Niri config, waybar config, or bin/ scripts | VERIFIED | `grep -rn "waystt\|stt-toggle\|stt-status\|custom/stt" config/ bin/` returns no matches |
| 5 | No waystt references remain in flake.nix (Phase 1 regression confirmed clean) | VERIFIED | `grep -n "waystt" flake.nix` returns no matches |
| 6 | bin/stt-toggle.sh does not exist | VERIFIED | `test ! -f bin/stt-toggle.sh` passes; confirmed deleted in commit `42ad96d` |
| 7 | config/waybar/scripts/stt-status.sh does not exist | VERIFIED | `test ! -f config/waybar/scripts/stt-status.sh` passes; confirmed deleted in commit `42ad96d` |
| 8 | nix flake check passes with all changes applied | VERIFIED | `nix flake check` exits 0 for mischief, intrepid, and vigilant (only non-fatal crane version warning present) |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `hosts/common/home.nix` | Voxtype HM module config with service, hotkey, model, PATH workaround | VERIFIED | Contains `programs.voxtype` block (lines 51-74) and `systemd.user.services.voxtype` PATH override (lines 77-83); 34 lines added in commit `753f260` |
| `config/niri/config.kdl` | Niri keybindings without waystt entries | VERIFIED | No `MOD+R`, `MOD+Shift+R`, or waystt references anywhere in file; 4 lines removed in commit `42ad96d` |
| `config/waybar/config.jsonc` | Waybar config without custom/stt module | VERIFIED | `modules-right` array is `["pulseaudio","network","bluetooth","battery","tray"]` — no `custom/stt`; module definition absent; 9 lines removed in commit `42ad96d` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `hosts/common/home.nix` | `programs.voxtype.service.enable` | HM module creates systemd user service | WIRED | `service.enable = true` at line 55; HM module source confirms this generates a systemd unit with `WantedBy = ["graphical-session.target"]` |
| `hosts/common/home.nix` | `systemd.user.services.voxtype` | PATH environment override for bug #253 | WIRED | Block at lines 77-83 adds `Service.Environment` with PATH; this is an additive merge onto the unit created by the HM module (module does not set Environment, so no mkForce needed — confirmed in module source) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| STT-01 | 02-01-PLAN | Voxtype daemon running as systemd user service on all three hosts | SATISFIED | `service.enable = true` in common `home.nix`; applies to all three hosts; `nix flake check` confirms all configurations evaluate |
| STT-02 | 02-01-PLAN | Whisper base.en model configured for transcription | SATISFIED | `model.name = "base.en"` at `home.nix:57` |
| STT-03 | 02-01-PLAN | Text injection at cursor working via wtype/ydotool | SATISFIED | `output.mode = "type"` and `fallback_to_clipboard = true` configured; PATH workaround ensures wtype (bundled in voxtype package) and ydotool are reachable at runtime; `ydotool` enabled via `programs.ydotool.enable` in `configuration.nix:95` |
| STT-04 | 02-01-PLAN | Service PATH workaround applied for upstream bug #253 | SATISFIED | `systemd.user.services.voxtype.Service.Environment` set in `home.nix:79-81` |
| PTT-01 | 02-01-PLAN | Push-to-talk working via voxtype's built-in evdev hotkey mode | SATISFIED | `settings.hotkey.enabled = true` and `mode = "push_to_talk"` at `home.nix:61,64` |
| PTT-02 | 02-01-PLAN | Hotkey configured as Alt_R + Menu combo | SATISFIED | `key = "MENU"`, `modifiers = ["RIGHTALT"]` at `home.nix:62-63` |
| PTT-03 | 02-01-PLAN | Voxtype hotkey uses evdev (not compositor bindings) | SATISFIED | No voxtype keybindings in `config/niri/config.kdl`; evdev hotkey configured in voxtype settings block |
| REM-01 | 02-01-PLAN | Waystt overlay removed from flake.nix | SATISFIED | `grep waystt flake.nix` returns no matches (Phase 1 regression clean) |
| REM-02 | 02-01-PLAN | Waystt package directory (packages/waystt/) removed | SATISFIED | `packages/waystt/` directory absent (Phase 1 regression clean) |
| REM-03 | 02-01-PLAN | Waystt-related Niri keybindings removed from config | SATISFIED | No `MOD+R`, `MOD+Shift+R`, or waystt references in `config/niri/config.kdl` |
| REM-04 | 02-01-PLAN | Waystt toggle/status scripts removed or replaced | SATISFIED | `bin/stt-toggle.sh` absent; `config/waybar/scripts/stt-status.sh` absent |

All 11 required requirements are satisfied. No orphaned requirements found (REQUIREMENTS.md traceability table maps all 11 IDs to Phase 2 and marks them Complete).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `config/niri/config.kdl` | 185 | `// TODO: Color picker - hyprpicker not installed` | Info | Pre-existing comment unrelated to Phase 2; does not affect goal |

No blockers or warnings found in Phase 2 modified files.

### Human Verification Required

The following items cannot be verified programmatically and require a live system test after `home-manager switch`:

#### 1. systemctl status confirms active/running

**Test:** On any host after `home-manager switch`, run `systemctl --user status voxtype`
**Expected:** Status shows `active (running)` and ExecStart contains the voxtype daemon path; no `Failed` or `not found` state
**Why human:** The service unit is correctly defined in Nix, but systemd startup requires the actual model file (`base.en`) to be downloaded at activation time and the audio stack (PipeWire) to be running. Cannot verify runtime state from static analysis.

#### 2. Push-to-talk triggers recording and text injection

**Test:** With voxtype running, hold Right Alt + Menu key, speak a phrase, release
**Expected:** Transcribed text appears at cursor position in any text input field
**Why human:** End-to-end PTT behavior depends on evdev device enumeration, audio capture, whisper inference, and wtype injection — all runtime behaviors.

#### 3. PATH workaround resolves wtype at runtime

**Test:** Check voxtype service environment: `systemctl --user show voxtype --property=Environment`
**Expected:** PATH contains both `/run/current-system/sw/bin` and the voxtype store path `/bin`
**Why human:** The additive merge in home.nix generates the correct unit file, but runtime resolution of the store path interpolation (`${inputs.voxtype.packages...}`) requires the built system.

### Gaps Summary

No gaps. All 8 must-have truths are verified by direct codebase inspection. All 11 Phase 2 requirement IDs (STT-01 through STT-04, PTT-01 through PTT-03, REM-01 through REM-04) are satisfied with concrete implementation evidence. The flake evaluates cleanly for all three hosts.

The phase goal — "Voxtype daemon runs on all three hosts via systemd user service with evdev push-to-talk; waystt is fully removed with no conflicts" — is achieved in the codebase. Three human verification items remain but are runtime concerns only (not implementation gaps).

---

_Verified: 2026-03-22_
_Verifier: Claude (gsd-verifier)_
