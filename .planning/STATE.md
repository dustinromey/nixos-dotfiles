# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-20)

**Core value:** Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts with shared defaults and clean per-host overrides
**Current focus:** Phase 1 — Flake Foundation

## Current Position

Phase: 1 of 3 (Flake Foundation)
Plan: 1 of 1 in current phase (phase complete)
Status: Phase 1 complete — ready for Phase 2
Last activity: 2026-03-20 — Executed 01-01-PLAN.md; voxtype integrated, waystt removed

Progress: [███░░░░░░░] 33%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 7 min
- Total execution time: 7 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 (Flake Foundation) | 1 | 7 min | 7 min |

**Recent Trend:**
- Last 5 plans: 01-01 (7 min)
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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2: Upstream voxtype bug #253 — systemd service PATH workaround required; check if fixed in v0.6.4 before applying workaround
- Phase 3: vigilant Surface Laptop 4 AMD iGPU may give no meaningful Vulkan speedup; revisit at Phase 3 execution

## Session Continuity

Last session: 2026-03-20
Stopped at: Completed 01-01-PLAN.md — Phase 1 complete
Resume file: .planning/phases/02-daemon-activation/ (Phase 2 not yet planned)
