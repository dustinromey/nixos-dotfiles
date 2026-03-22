# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-20)

**Core value:** Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts with shared defaults and clean per-host overrides
**Current focus:** Phase 2 — Daemon Replacement

## Current Position

Phase: 2 of 4 (Daemon Replacement)
Plan: 1 of 1 in current phase (phase complete)
Status: Phase 2 complete — ready for Phase 3
Last activity: 2026-03-22 — Executed 02-01-PLAN.md; voxtype HM module activated, all waystt artifacts removed

Progress: [██████░░░░] 66%

## Performance Metrics

**Velocity:**
- Total plans completed: 2
- Average duration: 5 min
- Total execution time: 10 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 (Flake Foundation) | 1 | 7 min | 7 min |
| 02 (Daemon Replacement) | 1 | 3 min | 3 min |

**Recent Trend:**
- Last 5 plans: 01-01 (7 min), 02-01 (3 min)
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Vulkan over ROCm for AMD GPU acceleration — more portable, avoids ROCm complexity
- Home Manager module over NixOS module for user config — consistent with existing repo pattern
- Evdev hotkey mode for push-to-talk — Niri has no key-release bind; evdev is the only viable approach
- Waystt removal is atomic with keybinding update in Phase 2 — prevents partial state with both tools present
- [Phase 01]: programs.voxtype.package must be set explicitly — upstream module has no default; set to CPU default with lib.mkDefault so hosts can override to vulkan/rocm in Phase 3
- [Phase 01]: Pinned voxtype to v0.6.4 tag with nixpkgs.follows to prevent double evaluation
- [Phase 02-daemon-replacement]: wtype bundled in voxtype derivation — PATH workaround points to voxtype store path only, no separate pkgs.wtype needed
- [Phase 02-daemon-replacement]: No replacement Niri keybindings added — voxtype evdev handles push-to-talk at input layer without compositor binds

### Pending Todos

None yet.

### Roadmap Evolution

- Phase 4 added: Add claude-for-linux to NixOS setup

### Blockers/Concerns

- Phase 3: vigilant Surface Laptop 4 AMD iGPU may give no meaningful Vulkan speedup; revisit at Phase 3 execution

## Session Continuity

Last session: 2026-03-22
Stopped at: Completed 02-01-PLAN.md — Phase 2 complete
Resume file: .planning/phases/03-gpu-acceleration/
