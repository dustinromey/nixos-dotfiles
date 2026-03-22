---
phase: 03-gpu-acceleration-waybar
verified: 2026-03-22T00:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 3: GPU Acceleration + Waybar Verification Report

**Phase Goal:** Intrepid and vigilant use Vulkan-accelerated voxtype; mischief stays CPU-only; Waybar shows live voxtype recording status
**Verified:** 2026-03-22
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Intrepid uses the Vulkan voxtype package variant | VERIFIED | `hosts/intrepid/home.nix` line 14: `programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;` |
| 2 | Vigilant uses the Vulkan voxtype package variant | VERIFIED | `hosts/vigilant/home.nix` line 14: `programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;` |
| 3 | Mischief uses CPU-only default (no override) | VERIFIED | `hosts/mischief/home.nix` has no voxtype entry — inherits `lib.mkDefault` CPU package from common |
| 4 | PATH workaround uses `config.programs.voxtype.package` (not hardcoded) | VERIFIED | `hosts/common/home.nix` line 81: `"PATH=/run/current-system/sw/bin:${config.programs.voxtype.package}/bin"` |
| 5 | Waybar shows a custom/stt module in the status bar | VERIFIED | `config/waybar/config.jsonc` line 12: `"modules-right": ["custom/stt", ...]` and module definition at lines 92-103 |
| 6 | The STT module uses `voxtype status --follow --format json` | VERIFIED | `config/waybar/config.jsonc` line 93: `"exec": "voxtype status --follow --format json"` |
| 7 | CSS classes match voxtype state names (idle, recording, transcribing, stopped) | VERIFIED | `config/waybar/style.css` lines 128-143: all four state classes present; old `.ready`/`.inactive` classes absent |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `hosts/common/home.nix` | Fixed PATH workaround using `config.programs.voxtype.package`; package assignment with `lib.mkDefault`; Waybar systemd PATH | VERIFIED | Line 54 has `lib.mkDefault`; line 81 has `config.programs.voxtype.package` in voxtype service; lines 87-93 add Waybar service PATH |
| `hosts/intrepid/home.nix` | Vulkan package override for AMD desktop | VERIFIED | Contains `inputs.voxtype.packages.${pkgs.system}.vulkan` |
| `hosts/vigilant/home.nix` | Vulkan package override for AMD Surface Laptop | VERIFIED | Contains `inputs.voxtype.packages.${pkgs.system}.vulkan` |
| `config/waybar/config.jsonc` | custom/stt module definition using `voxtype status` | VERIFIED | Module present in `modules-right` and as full block definition |
| `config/waybar/style.css` | CSS rules for voxtype state classes | VERIFIED | `#custom-stt.idle`, `.recording`, `.transcribing`, `.stopped` all present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `hosts/common/home.nix` | `config.programs.voxtype.package` | systemd PATH environment variable | WIRED | `Service.Environment` pattern on voxtype service uses self-reference |
| `hosts/intrepid/home.nix` | `inputs.voxtype.packages` | package override | WIRED | `programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan` |
| `hosts/vigilant/home.nix` | `inputs.voxtype.packages` | package override | WIRED | Same pattern as intrepid |
| `config/waybar/config.jsonc` | `voxtype status --follow` | exec field in custom/stt | WIRED | `"exec": "voxtype status --follow --format json"` present |
| `config/waybar/style.css` | CSS classes from format-icons keys | #custom-stt.(idle|recording|transcribing|stopped) | WIRED | All four state classes present; format-icons keys match exactly |
| `hosts/common/home.nix` | Waybar systemd service | `Service.Environment` PATH | WIRED | Lines 87-93: `systemd.user.services.waybar.Service.Environment` includes `config.programs.voxtype.package` bin |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GPU-01 | 03-01-PLAN.md | Vulkan package variant used on intrepid | SATISFIED | `hosts/intrepid/home.nix` overrides to `.vulkan` variant |
| GPU-02 | 03-01-PLAN.md | Vulkan package variant used on vigilant | SATISFIED | `hosts/vigilant/home.nix` overrides to `.vulkan` variant |
| GPU-03 | 03-01-PLAN.md | CPU-only default on mischief | SATISFIED | `hosts/mischief/home.nix` has no voxtype override; inherits `lib.mkDefault` from common |
| BAR-01 | 03-02-PLAN.md | Waybar STT status updated to query voxtype state | SATISFIED | `config.jsonc` exec uses `voxtype status --follow --format json` (streaming protocol) |
| BAR-02 | 03-02-PLAN.md | Waybar module shows recording/idle status | SATISFIED | `custom/stt` in modules-right with format-icons for all states; CSS styles each state |

No orphaned requirements found — all five IDs declared in plan frontmatter are accounted for and satisfied.

---

### Anti-Patterns Found

None. No TODO/FIXME/placeholder comments found in any modified file. No stub implementations detected. No empty handlers.

---

### Human Verification Required

#### 1. Vulkan backend active on AMD hosts

**Test:** After `sudo nixos-rebuild switch` on intrepid or vigilant, check voxtype service logs: `journalctl --user -u voxtype | grep -i vulkan`
**Expected:** Log line indicating Vulkan/GPU backend initialized (not CPU fallback)
**Why human:** Cannot verify at runtime from static code analysis — requires actual rebuild and log inspection on AMD hardware

#### 2. Waybar STT module updates in real time

**Test:** Trigger push-to-talk on intrepid or vigilant and observe Waybar STT module while recording, then after release
**Expected:** Module icon changes from idle state to recording state during hold, then to transcribing after release, then back to idle
**Why human:** Real-time UI behavior and streaming JSON protocol responsiveness cannot be verified from code alone

---

### Gaps Summary

No gaps. All must-haves verified at all three levels (exists, substantive, wired). All five requirement IDs satisfied. No anti-patterns found. Two items flagged for human verification (runtime behavior on AMD hardware) but these do not constitute failures — the configuration is correct.

---

**Note on Waybar PATH implementation deviation:** Plan 03-02 specified `systemd.user.services.waybar.path = [package]` (list form) but home-manager's `path` option requires an attrset. The implementation correctly used `Service.Environment` with an explicit PATH string instead — same pattern as the voxtype service. The key link (voxtype reachable from Waybar exec) is fully wired via `config.programs.voxtype.package` reference.

---

_Verified: 2026-03-22_
_Verifier: Claude (gsd-verifier)_
