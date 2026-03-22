# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-20)

**Core value:** Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts with shared defaults and clean per-host overrides
**Current focus:** Phase 3 — GPU Acceleration & Waybar

## Current Position

Phase: 3 of 4 (GPU Acceleration & Waybar)
Plan: 1 of 2 complete in current phase
Status: Phase 3 in progress — 03-01 complete, 03-02 pending
Last activity: 2026-03-22 — Executed 03-01-PLAN.md; Vulkan voxtype enabled on AMD hosts

Progress: [███████░░░] 75%

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
| 03 (GPU Acceleration & Waybar) | 1 | 4 min | 4 min |

**Recent Trend:**
- Last 5 plans: 01-01 (7 min), 02-01 (3 min), 03-01 (4 min)
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
- [Phase 03-gpu-acceleration-waybar]: Vulkan over CPU-only for AMD hosts: intrepid and vigilant override voxtype package to Vulkan variant; mischief inherits CPU default via lib.mkDefault

### Pending Todos

None yet.

### Roadmap Evolution

- Phase 4 added: Add claude-for-linux to NixOS setup

### Blockers/Concerns

- Phase 3: vigilant Surface Laptop 4 AMD iGPU may give no meaningful Vulkan speedup; revisit at Phase 3 execution

## Session Continuity

Last session: 2026-03-22
Stopped at: Completed 03-01-PLAN.md — Vulkan voxtype enabled on AMD hosts
Resume file: .planning/phases/03-gpu-acceleration-waybar/
