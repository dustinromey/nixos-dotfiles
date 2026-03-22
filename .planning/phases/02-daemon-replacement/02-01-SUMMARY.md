---
phase: 02-daemon-replacement
plan: 01
subsystem: infra
tags: [voxtype, systemd, niri, waybar, speech-to-text, evdev, push-to-talk]

# Dependency graph
requires:
  - phase: 01-flake-foundation
    provides: voxtype flake input pinned at v0.6.4, HM module import, nixpkgs.follows
provides:
  - Voxtype systemd user service configured via HM module (base.en, evdev PTT, type output)
  - Bug #253 PATH workaround in systemd.user.services.voxtype
  - All waystt artifacts removed (Niri keybindings, waybar module, toggle/status scripts)
affects: [03-gpu-acceleration, post-deployment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "systemd.user.services.<name> additive merge for HM module service environment overrides"
    - "programs.<module> package set explicitly when upstream module has no default"

key-files:
  created: []
  modified:
    - hosts/common/home.nix
    - config/niri/config.kdl
    - config/waybar/config.jsonc
  deleted:
    - bin/stt-toggle.sh
    - config/waybar/scripts/stt-status.sh

key-decisions:
  - "wtype confirmed bundled in voxtype derivation — PATH workaround points to voxtype store path only (no separate pkgs.wtype needed)"
  - "No replacement keybindings added to Niri — voxtype uses evdev hotkeys, compositor binds not needed"

patterns-established:
  - "systemd.user.services.voxtype: additive merge pattern for adding Environment to HM module-managed services without mkForce"

requirements-completed: [STT-01, STT-02, STT-03, STT-04, PTT-01, PTT-02, PTT-03, REM-01, REM-02, REM-03, REM-04]

# Metrics
duration: 3min
completed: 2026-03-22
---

# Phase 2 Plan 01: Daemon Replacement Summary

**Voxtype HM module activated as systemd user service with MENU+RIGHTALT evdev push-to-talk, and all waystt artifacts atomically removed from Niri, Waybar, and bin/**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-22T11:21:22Z
- **Completed:** 2026-03-22T11:25:08Z
- **Tasks:** 2
- **Files modified:** 3 modified, 2 deleted

## Accomplishments

- Voxtype HM module fully configured: service.enable = true, model base.en, MENU+RIGHTALT push-to-talk, type output with clipboard fallback, whisper language en
- Bug #253 PATH workaround applied via systemd.user.services.voxtype additive merge
- All waystt artifacts removed: Niri Mod+R/Mod+Shift+R keybindings, waybar custom/stt module, stt-toggle.sh, stt-status.sh
- nix flake check passes for all three hosts (mischief, intrepid, vigilant)
- Phase 1 REM regressions confirmed clean: no waystt in flake.nix, packages/waystt/ absent

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure voxtype HM module with daemon, hotkey, and PATH workaround** - `753f260` (feat)
2. **Task 2: Remove all waystt artifacts from Niri, Waybar, and scripts** - `42ad96d` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `hosts/common/home.nix` - Added programs.voxtype config block and systemd PATH workaround
- `config/niri/config.kdl` - Removed waystt keybindings (Mod+R, Mod+Shift+R)
- `config/waybar/config.jsonc` - Removed custom/stt from modules-right and deleted module definition
- `bin/stt-toggle.sh` - Deleted
- `config/waybar/scripts/stt-status.sh` - Deleted

## Decisions Made

- wtype is bundled inside the voxtype derivation store path — the PATH workaround pointing to `${inputs.voxtype.packages.${pkgs.system}.default}/bin` is sufficient without adding a separate `pkgs.wtype` entry
- No replacement Niri keybindings added — voxtype's evdev hotkey mode handles push-to-talk at the input layer, making compositor-level binds unnecessary and redundant

## Deviations from Plan

None - plan executed exactly as written. The voxtype config was confirmed already present in home.nix from Phase 1 execution but uncommitted; staged and committed as Task 1.

## Issues Encountered

None. `nix flake check` passed on first run after both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- STT system swap from waystt to voxtype is complete across all three hosts
- Phase 3 (GPU acceleration) can proceed: voxtype is running CPU inference with base.en; GPU variants (vulkan/rocm) can override the package per host
- Concern from STATE.md still applies: vigilant Surface Laptop 4 AMD iGPU may give no meaningful Vulkan speedup — revisit at Phase 3 execution

---
*Phase: 02-daemon-replacement*
*Completed: 2026-03-22*
