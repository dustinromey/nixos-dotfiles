---
phase: 03-gpu-acceleration-waybar
plan: 01
subsystem: voxtype-gpu
tags: [gpu, vulkan, voxtype, amd, home-manager]
dependency_graph:
  requires: []
  provides: [vulkan-voxtype-amd, fixed-path-workaround]
  affects: [hosts/common/home.nix, hosts/intrepid/home.nix, hosts/vigilant/home.nix]
tech_stack:
  added: []
  patterns: [lib.mkDefault for host overrides, config self-reference in systemd env]
key_files:
  created: []
  modified:
    - hosts/common/home.nix
    - hosts/intrepid/home.nix
    - hosts/vigilant/home.nix
decisions:
  - "PATH workaround uses config.programs.voxtype.package so overrides propagate correctly"
  - "lib.mkDefault on common package assignment allows host files to override cleanly"
  - "mischief unchanged — inherits CPU-only default via lib.mkDefault"
metrics:
  duration: 4 min
  completed: 2026-03-22
  tasks_completed: 2
  files_modified: 3
---

# Phase 03 Plan 01: GPU Acceleration (Vulkan voxtype) Summary

**One-liner:** Vulkan-accelerated voxtype on AMD hosts (intrepid, vigilant) via per-host package overrides with fixed systemd PATH workaround using config self-reference.

## What Was Done

Enabled Vulkan-accelerated voxtype transcription on AMD hosts while keeping the CPU-only default on mischief (Intel). Two changes were needed in common home.nix and one each in the AMD host home files.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix PATH workaround to use evaluated config | 10029dd | hosts/common/home.nix |
| 2 | Add Vulkan package override to AMD hosts | 8d5d21e | hosts/intrepid/home.nix, hosts/vigilant/home.nix |

## Decisions Made

1. **lib.mkDefault on common package assignment** — Wraps `programs.voxtype.package` in common home.nix with `lib.mkDefault` so host files can override to the Vulkan variant without conflict.

2. **config self-reference in systemd PATH** — Changed the PATH workaround from hardcoded `inputs.voxtype.packages.${pkgs.system}.default` to `config.programs.voxtype.package`. This ensures Vulkan hosts get the Vulkan binary in their service PATH, not the CPU binary.

3. **mischief inherits by default** — No change to mischief/home.nix. The lib.mkDefault in common ensures it keeps the CPU-only package without needing an explicit assignment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] Added `lib` to function argument set in common home.nix**
- **Found during:** Task 1
- **Issue:** `lib.mkDefault` was added to common home.nix but `lib` was not in the function argument set. The `...` catch-all does not bind named variables — explicit listing required.
- **Fix:** Added `lib` as explicit argument alongside `config`, `pkgs`, `inputs`.
- **Files modified:** hosts/common/home.nix
- **Commit:** 10029dd

## Verification Results

All criteria confirmed passing:
- `nix flake check` passes for all three hosts
- `grep "config.programs.voxtype.package" hosts/common/home.nix` returns PATH workaround line
- `grep "vulkan" hosts/intrepid/home.nix hosts/vigilant/home.nix` shows overrides in both AMD hosts
- `grep "voxtype" hosts/mischief/home.nix` returns nothing (no override)
- All modified Nix files pass `nixfmt-rfc-style` formatting
