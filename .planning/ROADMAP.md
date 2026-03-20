# Roadmap: Romey NixOS — Voxtype Integration

## Overview

This roadmap replaces waystt with voxtype across all three hosts (mischief, intrepid, vigilant). The work proceeds in three phases: wire the flake input and system module, activate the Home Manager daemon with push-to-talk and atomic waystt removal, then enable per-host GPU acceleration and update the Waybar status widget. Each phase delivers a verifiable, working state before the next begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Flake Foundation** - Add voxtype flake input and import NixOS module in common configuration
- [ ] **Phase 2: Daemon + Replacement** - Activate voxtype daemon on all hosts with push-to-talk; atomically remove waystt
- [ ] **Phase 3: GPU Acceleration + Waybar** - Enable Vulkan on AMD hosts and update Waybar STT status widget

## Phase Details

### Phase 1: Flake Foundation
**Goal**: Voxtype is available as a system package with the nixosModule imported and nixpkgs double-evaluation prevented
**Depends on**: Nothing (first phase)
**Requirements**: FLAKE-01, FLAKE-02, FLAKE-03
**Success Criteria** (what must be TRUE):
  1. `nix flake check` passes with voxtype input present and nixpkgs.follows set
  2. `nixos-rebuild switch` succeeds on any host without errors from the voxtype nixosModule import
  3. Voxtype is available as a system package (visible in `nix path-info`)
**Plans**: TBD

### Phase 2: Daemon + Replacement
**Goal**: Voxtype daemon runs on all three hosts via systemd user service with evdev push-to-talk; waystt is fully removed with no conflicts
**Depends on**: Phase 1
**Requirements**: STT-01, STT-02, STT-03, STT-04, PTT-01, PTT-02, PTT-03, REM-01, REM-02, REM-03, REM-04
**Success Criteria** (what must be TRUE):
  1. `systemctl --user status voxtype` shows active/running on all three hosts after rebuild
  2. Holding the evdev hotkey (Alt_R + Menu) starts recording; releasing stops and injects transcribed text at cursor
  3. Waystt overlay is absent from flake.nix and packages/waystt/ directory is gone; `nix flake check` still passes
  4. Old waystt keybindings are removed from Niri config and no dead references to waystt toggle scripts remain
**Plans**: TBD

### Phase 3: GPU Acceleration + Waybar
**Goal**: Intrepid and vigilant use Vulkan-accelerated voxtype; mischief stays CPU-only; Waybar shows live voxtype recording status
**Depends on**: Phase 2
**Requirements**: GPU-01, GPU-02, GPU-03, BAR-01, BAR-02
**Success Criteria** (what must be TRUE):
  1. Intrepid and vigilant report Vulkan backend active in voxtype logs after rebuild
  2. Mischief remains on CPU-only package (no Vulkan override in mischief home.nix)
  3. Waybar STT module reflects recording/idle state in real time while using push-to-talk
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Foundation | 0/? | Not started | - |
| 2. Daemon + Replacement | 0/? | Not started | - |
| 3. GPU Acceleration + Waybar | 0/? | Not started | - |
