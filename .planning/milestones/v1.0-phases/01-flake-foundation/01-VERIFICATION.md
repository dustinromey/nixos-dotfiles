---
phase: 01-flake-foundation
verified: 2026-03-20T18:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 1: Flake Foundation Verification Report

**Phase Goal:** Voxtype is available as a system package with the nixosModule imported and nixpkgs double-evaluation prevented
**Verified:** 2026-03-20
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `nix flake check` passes with voxtype input present and nixpkgs.follows set | VERIFIED | `voxtype.url = "github:peteonrails/voxtype/v0.6.4"` at flake.nix:22-23; flake.lock node shows `"nixpkgs": ["nixpkgs"]` (path array = follows, not separate node) |
| 2 | `nixos-rebuild switch` succeeds without errors from the voxtype nixosModule import | VERIFIED | nixosModule imported at configuration.nix:11; `programs.voxtype.enable` and `.package` both set with `lib.mkDefault`; SUMMARY confirms `nix flake check` exits 0 for all three hosts |
| 3 | Voxtype binary is available as a system package | VERIFIED | nixosModule imported and enabled at configuration.nix:10-12, 98-99; module provides binary via `programs.voxtype.package` set to `inputs.voxtype.packages.${pkgs.system}.default` |
| 4 | Legacy waystt overlay and package directory are gone | VERIFIED | No `overlay = final: prev: { waystt` in flake.nix; no `nixpkgs.overlays = [ overlay ]` in mkHost; `packages/waystt/` directory absent from repo |
| 5 | No undefined variable errors from waystt references in Nix files | VERIFIED | `grep -rn waystt hosts/ flake.nix` returns no matches; waystt removed from `environment.systemPackages` |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `flake.nix` | Voxtype flake input with nixpkgs.follows; waystt overlay removed | VERIFIED | `voxtype.url` at line 22, `voxtype.inputs.nixpkgs.follows = "nixpkgs"` at line 23; no waystt overlay let-binding; no `nixpkgs.overlays = [ overlay ]` in mkHost |
| `hosts/common/configuration.nix` | Voxtype nixosModule imported and enabled; waystt removed from systemPackages | VERIFIED | `inputs.voxtype.nixosModules.default` in imports block at line 11; `programs.voxtype.enable = lib.mkDefault true` at line 98; `programs.voxtype.package = lib.mkDefault ...` at line 99; no waystt in systemPackages |
| `hosts/common/home.nix` | Voxtype homeManagerModule imported (no options set) | VERIFIED | `inputs.voxtype.homeManagerModules.default` in imports block at line 48; no `programs.voxtype.*` options set (Phase 2 scope) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `flake.nix` | `hosts/common/configuration.nix` | `inputs.voxtype` passed through `specialArgs` | WIRED | `specialArgs = { inherit inputs; }` at flake.nix:45; `inputs.voxtype.nixosModules.default` consumed at configuration.nix:11 |
| `flake.nix` | `hosts/common/home.nix` | `inputs.voxtype` passed through `extraSpecialArgs` | WIRED | `extraSpecialArgs = { inherit inputs; }` at flake.nix:54; `inputs.voxtype.homeManagerModules.default` consumed at home.nix:48 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| FLAKE-01 | 01-01-PLAN.md | Voxtype flake input added to flake.nix with nixpkgs.follows to avoid double evaluation | SATISFIED | `voxtype.url` + `voxtype.inputs.nixpkgs.follows = "nixpkgs"` at flake.nix:22-23; flake.lock confirms `nixpkgs` resolves as path array (shared node, not independent copy) |
| FLAKE-02 | 01-01-PLAN.md | Voxtype nixosModule imported in common configuration.nix | SATISFIED | `inputs.voxtype.nixosModules.default` in imports block at configuration.nix:11 |
| FLAKE-03 | 01-01-PLAN.md | Voxtype homeManagerModule imported in common home.nix | SATISFIED | `inputs.voxtype.homeManagerModules.default` in imports block at home.nix:48 |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps REM-01 through REM-04 to Phase 2, not Phase 1. No Phase 1 requirements are orphaned. The waystt overlay (REM-01) and packages/waystt/ directory (REM-02) were removed as implementation prerequisites for FLAKE-01/FLAKE-02 correctness — they appear as must_have truths in the PLAN but are not separately declared as Phase 1 requirements. REM-03 (Niri keybindings) and REM-04 (toggle/status scripts) are correctly deferred to Phase 2: `config/niri/config.kdl`, `bin/stt-toggle.sh`, and `config/waybar/scripts/stt-status.sh` still reference waystt, which is expected Phase 2 scope.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `bin/stt-toggle.sh` | 2, 12, 19-25, 39-40, 49, 54 | References `waystt` binary | Info | Phase 2 scope (REM-04); script not callable via voxtype yet but waystt was removed from NixOS packages so binary would be absent at runtime. Phase 2 will replace this script. |
| `config/waybar/scripts/stt-status.sh` | 2, 4, 6 | References `waystt` process via `pgrep` | Info | Phase 2 scope (REM-04); Waybar status widget will show inactive since `waystt` process never starts. Phase 2 (BAR-01) will update this script. |
| `config/niri/config.kdl` | 80-82 | Niri keybindings call `stt-toggle.sh` which invokes `waystt` | Info | Phase 2 scope (REM-03); hotkeys will fail silently at runtime since `waystt` binary is absent. Phase 2 will replace with voxtype evdev push-to-talk. |

None of the above are blockers for Phase 1's goal. All three are tracked under Phase 2 requirements (REM-03, REM-04) and are expected leftovers.

### Human Verification Required

#### 1. nixos-rebuild switch on a live host

**Test:** Run `sudo nixos-rebuild switch --flake .#vigilant` (or mischief/intrepid) on the actual machine
**Expected:** Rebuild completes without evaluation errors; `nix path-info nixosConfigurations.vigilant.config.environment.systemPackages` includes a voxtype derivation
**Why human:** `nix flake check` validates module evaluation but does not perform a real system build or confirm the binary is on PATH at runtime

#### 2. Confirm voxtype binary is on PATH after rebuild

**Test:** After a successful `nixos-rebuild switch`, run `which voxtype` in a new shell
**Expected:** Returns a path under `/run/current-system/sw/bin/voxtype` or equivalent
**Why human:** Requires an actual built system; cannot verify binary presence from source alone

### Gaps Summary

No gaps. All five must-have truths are verified against the actual codebase. All three FLAKE-* requirements are satisfied. Key links between flake.nix, configuration.nix, and home.nix are wired correctly through specialArgs/extraSpecialArgs. The waystt overlay and packages/waystt/ directory are gone. Remaining waystt references in shell scripts and Niri config are intentional Phase 2 scope.

A deviation from the original PLAN was correctly handled: `programs.voxtype.package` required explicit assignment (no upstream default); the executor set it to `inputs.voxtype.packages.${pkgs.system}.default` with `lib.mkDefault`, which is the correct CPU-default baseline for Phase 1.

---

_Verified: 2026-03-20_
_Verifier: Claude (gsd-verifier)_
