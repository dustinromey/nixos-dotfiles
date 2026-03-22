---
phase: 03-gpu-acceleration-waybar
plan: 02
subsystem: waybar-stt
tags: [waybar, voxtype, systemd, css, jsonc]
dependency_graph:
  requires: [03-01-vulkan-voxtype]
  provides: [waybar-stt-module, waybar-voxtype-path]
  affects: [config/waybar/config.jsonc, config/waybar/style.css, hosts/common/home.nix]
tech_stack:
  added: []
  patterns: [custom waybar module with streaming JSON, systemd service PATH extension via Environment]
key_files:
  created: []
  modified:
    - config/waybar/config.jsonc
    - config/waybar/style.css
    - hosts/common/home.nix
decisions:
  - "Use Service.Environment PATH extension for Waybar (not systemd path= option) — home-manager's path option expects attrset, not list; Service.Environment matches existing voxtype pattern"
  - "config.programs.voxtype.package reference in Waybar PATH — ensures Vulkan variant resolves correctly on AMD hosts"
metrics:
  duration: 3 min
  completed: 2026-03-22
  tasks_completed: 2
  files_modified: 3
---

# Phase 03 Plan 02: Waybar STT Module Summary

**One-liner:** Live voxtype recording status in Waybar via streaming JSON protocol with corrected CSS state classes and systemd PATH extension using Service.Environment pattern.

## What Was Done

Added a custom/stt module to Waybar that shows real-time voxtype recording state (idle, recording, transcribing, stopped) using `voxtype status --follow --format json`. Fixed pre-existing wrong CSS class names (.ready, .inactive) to match voxtype's actual output. Added voxtype to Waybar's systemd service PATH so the exec command resolves at runtime.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add custom/stt module to Waybar config and fix CSS | d65a3e9 | config/waybar/config.jsonc, config/waybar/style.css |
| 2 | Add voxtype to Waybar systemd PATH | de90b4d | hosts/common/home.nix |

## Decisions Made

1. **Service.Environment for Waybar PATH** — The plan specified `systemd.user.services.waybar.path = [package]` but home-manager's `path` option requires an attrset, not a list. Used `Service.Environment` with an explicit PATH string instead — the same pattern already established for the voxtype service workaround. This keeps the config consistent and avoids introducing a second approach.

2. **config.programs.voxtype.package in Waybar PATH** — References the evaluated package (not a hardcoded store path) so AMD hosts running the Vulkan variant get the Vulkan binary in Waybar's PATH, not the CPU binary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] home-manager systemd path= option type mismatch**
- **Found during:** Task 2, first nix flake check attempt
- **Issue:** Plan specified `path = [ config.programs.voxtype.package ]` but home-manager's `systemd.user.services.<name>.path` option has type `attrset`, not list. Both the derivation form and the string form failed with the same type error.
- **Fix:** Used `Service.Environment = ["PATH=..."]` pattern matching the existing voxtype workaround in the same file. This is functionally equivalent — adds voxtype's bin to the service's PATH.
- **Files modified:** hosts/common/home.nix
- **Commit:** de90b4d

## Verification Results

All criteria confirmed passing:
- `nix flake check` passes for all three hosts (mischief, intrepid, vigilant)
- `config/waybar/config.jsonc` has "custom/stt" in modules-right and complete module definition with `voxtype status --follow --format json`
- `config/waybar/style.css` has #custom-stt.idle, .recording, .transcribing, .stopped — no .ready or .inactive classes
- `hosts/common/home.nix` has systemd.user.services.waybar with Service.Environment PATH including voxtype package bin
- All modified Nix files pass nixfmt formatting
