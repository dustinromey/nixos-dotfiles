---
phase: 01-flake-foundation
plan: 01
subsystem: infra
tags: [nix, flakes, voxtype, voice-to-text, nixos-modules, home-manager]

# Dependency graph
requires: []
provides:
  - voxtype flake input pinned to v0.6.4 with nixpkgs.follows
  - voxtype nixosModule imported and enabled in common/configuration.nix
  - voxtype homeManagerModule imported in common/home.nix
  - waystt overlay and packages/waystt/ directory removed
  - flake.lock updated with voxtype dependency tree
affects: [02-daemon-activation, 03-gpu-acceleration]

# Tech tracking
tech-stack:
  added: [voxtype v0.6.4]
  patterns: [flake input with nixpkgs.follows, programs.* enable with lib.mkDefault, separate nixosModule + homeManagerModule imports]

key-files:
  created: []
  modified:
    - flake.nix
    - hosts/common/configuration.nix
    - hosts/common/home.nix
    - flake.lock

key-decisions:
  - "programs.voxtype.package must be set explicitly — upstream module has no default; set to inputs.voxtype.packages.${pkgs.system}.default (CPU Whisper) with lib.mkDefault so hosts can override to vulkan/rocm in Phase 3"
  - "Pinned voxtype to v0.6.4 tag with nixpkgs.follows to prevent double evaluation"

patterns-established:
  - "NixOS module import in common/configuration.nix imports block, not in mkHost modules list"
  - "Home Manager module import added as bare import in imports block with no options set (Phase 2 configures programs.voxtype.*)"

requirements-completed: [FLAKE-01, FLAKE-02, FLAKE-03]

# Metrics
duration: 7min
completed: 2026-03-20
---

# Phase 1 Plan 01: Flake Foundation Summary

**Voxtype v0.6.4 added as flake input, nixosModule enabled with CPU-default package, homeManagerModule imported bare, waystt overlay and package directory deleted**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-20T17:26:28Z
- **Completed:** 2026-03-20T17:34:18Z
- **Tasks:** 2
- **Files modified:** 4 (flake.nix, hosts/common/configuration.nix, hosts/common/home.nix, flake.lock) + 1 deleted (packages/waystt/default.nix)

## Accomplishments
- Added voxtype flake input pinned to v0.6.4 with nixpkgs.follows, replacing the hand-rolled waystt overlay
- Imported voxtype nixosModule and enabled it with lib.mkDefault true plus default CPU package in common/configuration.nix
- Imported voxtype homeManagerModule as bare import in common/home.nix (no options set; Phase 2 configures daemon)
- Removed waystt from environment.systemPackages and deleted packages/waystt/ directory
- nix flake check passes for all three hosts (mischief, intrepid, vigilant)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add voxtype input and remove waystt overlay from flake.nix** - `98bd24d` (feat)
2. **Task 2: Import voxtype modules and remove waystt from systemPackages** - `069e299` (feat)

**Plan metadata:** (docs commit follows this summary)

## Files Created/Modified
- `flake.nix` - Added voxtype input (v0.6.4, nixpkgs.follows); removed waystt overlay let-binding and nixpkgs.overlays from mkHost
- `hosts/common/configuration.nix` - Added imports block with voxtype nixosModule; programs.voxtype.enable and .package with lib.mkDefault; removed waystt from systemPackages
- `hosts/common/home.nix` - Added imports block with voxtype homeManagerModule (bare)
- `flake.lock` - Added voxtype, voxtype/flake-utils, voxtype/flake-utils/systems entries
- `packages/waystt/default.nix` - Deleted

## Decisions Made
- Set `programs.voxtype.package = lib.mkDefault inputs.voxtype.packages.${pkgs.system}.default` — the upstream nixosModule requires an explicit package value with no built-in default. The CPU-only default is safe for all hosts; Phase 3 will override to vulkan on AMD hosts.
- Pinned to v0.6.4 tag per user decision from planning phase.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added required programs.voxtype.package option**
- **Found during:** Task 2 (Import voxtype modules and remove waystt from systemPackages)
- **Issue:** The voxtype nixosModule defines `programs.voxtype.package` as a required option with no default value. Enabling `programs.voxtype.enable = true` without setting `package` caused `nix flake check` to fail with: "The option 'programs.voxtype.package' was accessed but has no value defined."
- **Fix:** Added `programs.voxtype.package = lib.mkDefault inputs.voxtype.packages.${pkgs.system}.default;` alongside the enable option in common/configuration.nix
- **Files modified:** hosts/common/configuration.nix
- **Verification:** nix flake check exits 0 for all three hosts
- **Committed in:** 069e299 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Required fix for evaluation correctness. No scope creep — the package chosen (CPU default) is the expected Phase 1 baseline; Phase 3 will override to GPU-accelerated variant.

## Issues Encountered
- crane (voxtype build dependency) emits a warning: "crane requires at least nixpkgs-25.11, supplied nixpkgs-25.05". This is a warning only, not an error — nix flake check passes. The warning does not affect runtime correctness. Tracked for awareness when upgrading to nixpkgs-25.11.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Voxtype is available system-wide on all hosts as environment.systemPackages via the nixosModule
- Phase 2 (daemon activation) can now set programs.voxtype service options in home.nix and configure hotkey
- Phase 3 (GPU acceleration) can override programs.voxtype.package to inputs.voxtype.packages.x86_64-linux.vulkan on intrepid and vigilant
- Blocker noted from planning: upstream voxtype bug #253 (systemd service PATH) — check if fixed in v0.6.4 before Phase 2 applies workaround

---
*Phase: 01-flake-foundation*
*Completed: 2026-03-20*

## Self-Check: PASSED

- flake.nix: found
- hosts/common/configuration.nix: found
- hosts/common/home.nix: found
- .planning/phases/01-flake-foundation/01-01-SUMMARY.md: found
- packages/waystt/ directory: deleted (confirmed)
- Commit 98bd24d: found
- Commit 069e299: found
