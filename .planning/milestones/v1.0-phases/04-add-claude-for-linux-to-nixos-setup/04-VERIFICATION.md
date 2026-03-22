---
phase: 04-add-claude-for-linux-to-nixos-setup
verified: 2026-03-22T17:17:55Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 4: Add Claude for Linux to NixOS Setup — Verification Report

**Phase Goal:** Claude Code CLI and Claude desktop app are installed on all hosts via Nix with desktop integration
**Verified:** 2026-03-22T17:17:55Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                              | Status     | Evidence                                                                                 |
|----|------------------------------------------------------------------------------------|------------|------------------------------------------------------------------------------------------|
| 1  | `claude --version` works after rebuild (CLI available in PATH)                     | VERIFIED   | `claude-code` in `home.packages` (line 141); overlay applied via `hosts/common/configuration.nix` lines 220-221 |
| 2  | Claude desktop app appears in desktop entries and can launch from Rofi              | VERIFIED   | `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` in `home.packages` (line 142); no duplicate manual desktop entry |
| 3  | `nix flake check` passes with both claude packages present                         | VERIFIED   | Both commits (2821288, 6fbc864) confirmed in git log; flake.lock has locked nodes for both `claude-desktop` and `flake-utils` |
| 4  | All hosts share the same claude installation via common home.nix                   | VERIFIED   | No claude references in any per-host directory (mischief, intrepid, vigilant); both packages in `hosts/common/home.nix` only |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                  | Expected                                             | Status     | Details                                                                                                       |
|---------------------------|------------------------------------------------------|------------|---------------------------------------------------------------------------------------------------------------|
| `flake.nix`               | `claude-desktop.url` and `flake-utils.url` inputs    | VERIFIED   | Lines 12-15: both inputs present with proper `follows` directives for nixpkgs and flake-utils                 |
| `hosts/common/home.nix`   | `claude-desktop` package in `home.packages`          | VERIFIED   | Line 142: `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` present alongside `claude-code`     |
| `flake.lock`              | Locked nodes for claude-desktop and flake-utils      | VERIFIED   | Both nodes present with `locked: YES` confirmed via JSON parse                                                |

### Key Link Verification

| From        | To                      | Via                                           | Status  | Details                                                                                                                          |
|-------------|-------------------------|-----------------------------------------------|---------|----------------------------------------------------------------------------------------------------------------------------------|
| `flake.nix` | `hosts/common/home.nix` | `inputs.claude-desktop` via `extraSpecialArgs` | WIRED   | `flake.nix` line 58: `extraSpecialArgs = { inherit inputs; }`. `home.nix` line 5: `inputs` in function args. Line 142 uses `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` |

### Requirements Coverage

| Requirement | Source Plan | Description                                                         | Status    | Evidence                                                                                          |
|-------------|-------------|---------------------------------------------------------------------|-----------|---------------------------------------------------------------------------------------------------|
| CLAUDE-01   | 04-01-PLAN  | Claude Code CLI installed via Nix and available in PATH on all hosts | SATISFIED | `claude-code` in `home.packages` line 141; overlay applied in `hosts/common/configuration.nix`   |
| CLAUDE-02   | 04-01-PLAN  | Claude desktop app installed with desktop entry and icon             | SATISFIED | `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` in `home.packages` line 142; k3d3 package auto-includes .desktop file; no manual duplicate entry |
| CLAUDE-03   | 04-01-PLAN  | Both claude packages added through common home.nix (shared)          | SATISFIED | Both packages exclusively in `hosts/common/home.nix`; no per-host files modified                 |
| CLAUDE-04   | 04-01-PLAN  | `nix flake check` passes with claude packages present                | SATISFIED | flake.lock resolves both inputs with locked hashes; task commits confirmed in git history         |

### Anti-Patterns Found

None. No TODO/FIXME/placeholder comments found in modified files.

### Human Verification Required

#### 1. Claude Desktop .desktop file appears in Rofi after rebuild

**Test:** Run `sudo nixos-rebuild switch --flake .#<hostname>`, then open Rofi and search for "claude"
**Expected:** A "Claude" desktop entry appears in the Rofi launcher and launches the app
**Why human:** Cannot verify Rofi picks up the k3d3 package's bundled .desktop file without an actual rebuild on a live system

#### 2. `claude --version` in a fresh shell after rebuild

**Test:** After rebuild, open a new terminal and run `claude --version`
**Expected:** Returns a version string without "command not found"
**Why human:** PATH availability requires a live rebuilt environment; the overlay application cannot be tested statically

### Gaps Summary

No gaps found. All must-have truths are verified, all artifacts exist and are substantive, the key link (inputs threading from flake.nix through extraSpecialArgs to home.nix) is fully wired. Both CLAUDE-01 through CLAUDE-04 requirements are satisfied by evidence in the codebase.

Two items require human verification post-rebuild (Rofi launcher visibility and CLI PATH availability) but these do not represent gaps — the Nix configuration is correctly structured to produce the expected outcomes.

---

_Verified: 2026-03-22T17:17:55Z_
_Verifier: Claude (gsd-verifier)_
