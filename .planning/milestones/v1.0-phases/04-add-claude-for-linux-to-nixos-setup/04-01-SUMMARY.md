---
phase: 04-add-claude-for-linux-to-nixos-setup
plan: 01
subsystem: infra
tags: [nix, flake, home-manager, claude-desktop, claude-code]

# Dependency graph
requires:
  - phase: 01-flake-foundation
    provides: flake.nix structure with inputs threading via extraSpecialArgs
provides:
  - Claude Desktop Linux app available on all hosts via home.packages
  - claude-desktop flake input from k3d3/claude-desktop-linux-flake
  - flake-utils input as shared dependency
affects: []

# Tech tracking
tech-stack:
  added:
    - claude-desktop (k3d3/claude-desktop-linux-flake)
    - flake-utils (numtide/flake-utils)
  patterns:
    - Named flake package reference: inputs.claude-desktop.packages.${pkgs.system}.claude-desktop

key-files:
  created: []
  modified:
    - flake.nix
    - flake.lock
    - hosts/common/home.nix

key-decisions:
  - "Use claude-desktop (not claude-desktop-with-fhs) — FHS variant is only for MCP servers, out of scope"
  - "No manual xdg.desktopEntries for Claude Desktop — k3d3 package auto-includes .desktop file to avoid duplicates"
  - "flake-utils added as top-level input with follows from claude-desktop — prevents duplicate evaluation"

patterns-established:
  - "Named flake package pattern: inputs.X.packages.${pkgs.system}.package-name (same as Fresh text editor)"

requirements-completed: [CLAUDE-01, CLAUDE-02, CLAUDE-03, CLAUDE-04]

# Metrics
duration: 3min
completed: 2026-03-22
---

# Phase 4 Plan 01: Claude Desktop Linux Setup Summary

**Claude Desktop Linux app added to all hosts via common home.nix using k3d3/claude-desktop-linux-flake with flake-utils as shared dependency**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-22T17:11:49Z
- **Completed:** 2026-03-22T17:15:02Z
- **Tasks:** 2
- **Files modified:** 3 (flake.nix, flake.lock, hosts/common/home.nix)

## Accomplishments
- Added claude-desktop and flake-utils inputs to flake.nix with proper follows directives
- Updated flake.lock with resolved input hashes for claude-desktop and flake-utils
- Added claude-desktop package reference to common home.nix alongside existing claude-code
- All hosts (mischief, intrepid, vigilant) get both claude-code CLI and claude-desktop app via shared config

## Task Commits

Each task was committed atomically:

1. **Task 1: Add claude-desktop flake input with flake-utils dependency** - `2821288` (feat)
2. **Task 2: Add claude-desktop package to common home.nix** - `6fbc864` (feat)

**Plan metadata:** (docs commit — pending)

## Files Created/Modified
- `flake.nix` - Added flake-utils and claude-desktop inputs in the # Claude section
- `flake.lock` - Updated with resolved hashes for claude-desktop (b2b040c) and flake-utils (11707dc)
- `hosts/common/home.nix` - Added inputs.claude-desktop.packages.${pkgs.system}.claude-desktop to home.packages

## Decisions Made
- Use `claude-desktop` package (not `claude-desktop-with-fhs`) — FHS variant is for MCP servers only, out of scope per user decision
- No manual `xdg.desktopEntries` for Claude Desktop — the k3d3 package ships its own .desktop file; adding one would create a duplicate
- `flake-utils` added as a top-level input with `follows` from claude-desktop to avoid duplicating nixpkgs evaluation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `nixfmt-rfc-style` not in shell PATH; used `nix run nixpkgs#nixfmt-rfc-style` instead (standard workaround, no impact)
- `--update-input` flag deprecated; used as-is since it functioned correctly and produced the expected lock file update

## User Setup Required
None - no external service configuration required. After running `sudo nixos-rebuild switch --flake .#<hostname>`, both `claude` CLI and the Claude Desktop app will be available.

## Next Phase Readiness
- Phase 4 complete — Claude for Linux NixOS setup fully done
- Both claude-code CLI and claude-desktop app available on all hosts after next rebuild
- No blockers

## Self-Check: PASSED

- flake.nix: FOUND
- hosts/common/home.nix: FOUND
- 04-01-SUMMARY.md: FOUND
- Commit 2821288 (Task 1): FOUND
- Commit 6fbc864 (Task 2): FOUND

---
*Phase: 04-add-claude-for-linux-to-nixos-setup*
*Completed: 2026-03-22*
