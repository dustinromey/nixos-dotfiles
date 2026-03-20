# Project Research Summary

**Project:** NixOS voxtype speech-to-text integration (replacing waystt)
**Domain:** NixOS flake-based multi-host dotfiles — brownfield migration to voxtype
**Researched:** 2026-03-20
**Confidence:** MEDIUM

## Executive Summary

This project replaces a hand-rolled `waystt` NixOS package with the actively maintained `voxtype` flake (v0.6.4, Rust, whisper.cpp). The migration is a clean brownfield swap: voxtype provides first-class NixOS and Home Manager modules that eliminate the existing custom derivation, Vulkan patches, and manual config management. The core integration follows established NixOS flake patterns already used in this repo for `claude-code`, `ghostty`, `sops-nix`, and others — add flake input, import nixosModule in configuration.nix, import homeManagerModule in home.nix, and set per-host package variants.

The recommended approach for all three hosts is: CPU-only (default package) on mischief (Intel HD 520), and GPU-accelerated Vulkan package on intrepid and vigilant (both AMD). Push-to-talk activation requires special attention: niri has no key-release bind mechanism, so voxtype's built-in evdev hotkey mode must be used instead of compositor-driven `record start/stop` calls. This is the single highest-stakes design decision — the user is already in the `input` group, so evdev mode is ready to use. For bilingual EN/ES dictation, the `large-v3-turbo` model is required (smaller `.en` models do not support Spanish); on CPU, this model will be slower but still usable for push-to-talk sessions.

The critical risks are: (1) a confirmed open upstream bug (voxtype issue #253) where the systemd user service cannot find runtime injection tools — a one-line PATH workaround exists; (2) the waystt overlay must be removed atomically alongside voxtype activation to avoid competing daemons and wasted build time; and (3) nixpkgs double-evaluation if `voxtype.inputs.nixpkgs.follows = "nixpkgs"` is omitted. All three are easily mitigated with known fixes and are not blockers.

## Key Findings

### Recommended Stack

Voxtype v0.6.4 is the clear replacement for waystt. It ships pre-built Vulkan and CPU binaries as separate flake outputs (`packages.vulkan` and `packages.default`), a Home Manager module that generates `~/.config/voxtype/config.toml` from Nix attrsets, and a systemd user service — all of which waystt lacked entirely. The existing repo already has all system-level prerequisites in place: `programs.ydotool.enable = true`, `users.extraGroups = ["input"]`, PipeWire with PulseAudio compat. Adding voxtype introduces no new system dependencies.

**Core technologies:**
- `voxtype` flake (peteonrails/voxtype) v0.6.4 — STT daemon replacing waystt, actively maintained Rust binary with NixOS modules
- `packages.vulkan` — GPU-accelerated build for intrepid and vigilant (AMD); ~35x realtime vs ~7x CPU for larger models
- `packages.default` — CPU-only build for mischief (Intel HD 520); Vulkan inference is slower than CPU on Gen 9 iGPU
- `homeManagerModules.default` — generates config.toml, manages systemd user service, handles model provisioning
- `nixosModules.default` — system-level package install, ydotool integration, input group (already mostly present)
- Whisper `large-v3-turbo` model — EN/ES bilingual support at acceptable speed; base.en is faster but English-only

### Expected Features

The voxtype integration must deliver daily-driver dictation across all three hosts, declaratively configured, with no manual post-deploy steps.

**Must have (table stakes):**
- Push-to-talk activation (evdev hotkey mode on niri — compositor key-release unavailable)
- Text injection at cursor via wtype/ydotool fallback chain
- EN/ES bilingual support via `large-v3-turbo` model
- Offline local inference (whisper.cpp — no cloud dependency)
- NixOS declarative configuration via Home Manager module
- Reproducible across mischief, intrepid, and vigilant

**Should have (differentiators over waystt):**
- Per-host GPU-accelerated inference (Vulkan on AMD hosts)
- Waybar status indicator (voxtype writes a state file; script updated to query `voxtype status`)
- Audio feedback sound cues (zero-cost built-in themes in voxtype config)
- Word replacements for spoken punctuation (EN/ES conventions in TOML)
- Smart auto-submit (v0.6.4 feature; useful for chat/messaging workflows)

**Defer (v2+):**
- Remote GPU offload (vigilant transcribing on intrepid) — only if local GPU proves insufficient
- Toggle mode as alternative to push-to-talk
- ONNX engine variants — only if Whisper accuracy on Spanish degrades unacceptably

### Architecture Approach

The integration follows a two-layer module pattern consistent with the existing repo structure: `nixosModules.default` imported in `hosts/common/configuration.nix` for system-level concerns, and `homeManagerModules.default` imported in `hosts/common/home.nix` for the user service, config, and model. The only host-specific difference is the `programs.voxtype.package` attribute — set to `packages.default` in common, overridden to `packages.vulkan` in `hosts/intrepid/home.nix` and `hosts/vigilant/home.nix`. This is identical to the existing per-host GPU override pattern already in use for `hardware.graphics.extraPackages`.

**Major components:**
1. `flake.nix` inputs — pins voxtype flake version; must include `voxtype.inputs.nixpkgs.follows = "nixpkgs"` to avoid double nixpkgs
2. `hosts/common/configuration.nix` — imports `nixosModules.default`; ydotool and input group already present
3. `hosts/common/home.nix` — imports `homeManagerModules.default`; sets daemon, model, and shared settings
4. `hosts/{intrepid,vigilant}/home.nix` — overrides `programs.voxtype.package` to Vulkan variant
5. `config/niri/config.kdl` — updated keybindings; evdev mode means no compositor key-release needed
6. `config/waybar/scripts/stt-status.sh` — updated to query `voxtype status` instead of polling waystt process

### Critical Pitfalls

1. **Niri has no key-release bind** — use voxtype's built-in evdev hotkey (`hotkey.enabled = true`, the default); do NOT attempt `release=true` bind syntax in niri config — it does not exist and push-to-talk will never stop. User is already in `input` group so evdev mode works as-is.

2. **Service PATH bug (upstream issue #253)** — `service.enable = true` causes the systemd unit to start without access to injection tools; add `config.systemd.user.services.voxtype.Service.Environment = ["PATH=/run/current-system/sw/bin:${config.home.profileDirectory}/bin"]` as a workaround until upstream fixes it.

3. **Missing nixpkgs.follows** — voxtype's flake defaults to nixpkgs-unstable; always add `voxtype.inputs.nixpkgs.follows = "nixpkgs"` in flake.nix or builds will pull a second nixpkgs instance, doubling evaluation time.

4. **Waystt overlay must be removed atomically** — leaving the overlay in flake.nix while adding voxtype causes competing daemons and wastes build time; remove the overlay variable, its application in mkHost, and `packages/waystt/` in one commit.

5. **Vulkan package on mischief (Intel HD 520)** — Intel Gen 9 iGPU has no usable Vulkan for inference; always default to `packages.default` (CPU) in common and only override to `packages.vulkan` in AMD host files.

## Implications for Roadmap

Based on research, the build-order dependency graph from ARCHITECTURE.md maps cleanly to five phases:

### Phase 1: Flake Input and NixOS Module Integration
**Rationale:** Everything else depends on the flake input being wired in and the nixosModule imported. This is the foundation with the highest risk of subtle errors (double nixpkgs, overlay conflicts). Doing this in isolation makes it easy to verify correctness before adding user-level config.
**Delivers:** voxtype available as a system package; ydotool and input group confirmed; waystt overlay still present (not yet removed)
**Addresses:** Table stakes prerequisites
**Avoids:** Pitfall 3 (missing nixpkgs.follows), Pitfall 10 (ydotool option conflict with nixosModule)

### Phase 2: Home Manager Module Integration (CPU, Common Config)
**Rationale:** Get the daemon running on all hosts using the safe CPU-only default before introducing GPU variants. Validates the service, model download, and text injection on mischief first (lowest-risk host). Addresses the confirmed upstream bug (#253) with the PATH workaround.
**Delivers:** voxtype daemon running on all three hosts via systemd user service; `large-v3-turbo` model downloaded; text injection working; PATH workaround applied
**Uses:** `homeManagerModules.default`, `packages.default`, `large-v3-turbo` model
**Avoids:** Pitfall 2 (service PATH bug), Pitfall 6 (model download at build time requires network), Pitfall 8 (engine/model assertion)

### Phase 3: Niri Keybindings and waystt Removal
**Rationale:** Once the voxtype daemon is confirmed working, replace the old waystt bindings and remove the waystt package atomically. Bundling keybinding update with waystt removal prevents a state where both tools fight for the same keybind. The evdev hotkey approach for niri is confirmed here.
**Delivers:** Push-to-talk working via evdev; waystt fully removed (overlay, package dir, keybindings, toggle script); `bin/stt-toggle.sh` deleted or rewritten
**Avoids:** Pitfall 1 (niri key-release), Pitfall 4 (waystt overlay conflict), Pitfall 9 (dead toggle script)

### Phase 4: Per-Host GPU Acceleration (Vulkan on AMD)
**Rationale:** After core push-to-talk is validated on CPU, enable Vulkan acceleration on intrepid and vigilant. Separating this from Phase 2 isolates GPU-specific issues (wrong GPU selected, Vulkan init failure) from the baseline integration concerns.
**Delivers:** Vulkan-accelerated inference on intrepid and vigilant; mischief confirmed CPU-only; transcription latency meaningfully reduced on AMD hosts
**Uses:** `packages.vulkan` in per-host home.nix overrides
**Avoids:** Pitfall 5 (vulkan package on mischief)

### Phase 5: Waybar Status Widget and Quality-of-Life Features
**Rationale:** Cosmetic and convenience features that are non-blocking. The Waybar script update is low-risk but requires knowing voxtype's state API. Audio cues, word replacements, and smart auto-submit are zero-risk TOML additions once the core is stable.
**Delivers:** Waybar STT indicator updated to poll `voxtype status`; audio feedback enabled; word replacements configured; smart auto-submit enabled
**Avoids:** Pitfall 11 (waybar script polling waystt process)

### Phase Ordering Rationale

- **Phases 1-2 before 3:** The flake input and daemon must exist before keybindings can be tested. Removing waystt before voxtype is ready leaves no STT at all.
- **Phase 2 uses CPU default for all hosts:** Validates the common config path before introducing host-specific variation. GPU issues are isolated to Phase 4.
- **Phase 3 bundles waystt removal with keybinding update:** Atomic removal prevents partial states where both tools are present or keybindings reference a nonexistent command.
- **Phase 5 deferred:** Waybar is cosmetic; audio/word-replacement features are opt-in polish. Deferring keeps early phases focused on functional correctness.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** The `nixosModules.default` exact option names and their interaction with existing `programs.ydotool.enable` warrant a quick pre-task source read to confirm no option naming surprises.
- **Phase 3 (Niri evdev hotkey config):** The exact voxtype TOML syntax for evdev hotkey configuration (key name, `[hotkey]` section options) should be confirmed from voxtype docs before writing the task.

Phases with standard patterns (skip research-phase):
- **Phase 2:** Home Manager module import + service + model is a fully documented voxtype pattern; the PATH workaround is a one-liner.
- **Phase 4:** Per-host package override uses the identical pattern already established for GPU packages in this repo.
- **Phase 5:** TOML config additions; standard waybar custom module pattern already in use.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | voxtype flake source inspected directly; module option names confirmed from source; some option behavior inferred rather than tested end-to-end |
| Features | MEDIUM-HIGH | voxtype official site, GitHub README, and release notes consulted; niri key-release limitation confirmed via official wiki |
| Architecture | HIGH | Existing repo structure inspected directly; voxtype module layer structure confirmed from source; per-host override pattern already established in repo |
| Pitfalls | HIGH for 3 critical pitfalls | Niri key-release: official wiki (HIGH); service PATH bug: confirmed open GitHub issue (MEDIUM); nixpkgs follows: confirmed from flake.nix source (MEDIUM); others inferred from repo state inspection (HIGH) |

**Overall confidence:** MEDIUM — sufficient to execute all phases without additional pre-research. The open upstream bug (#253) is the main uncertainty; the workaround is known and the fix is expected in v0.6.4.

### Gaps to Address

- **voxtype `[hotkey]` evdev TOML syntax:** Exact key names and syntax for configuring the evdev hotkey in `config.toml` were not captured in detail. Confirm from voxtype CONFIGURATION.md before writing Phase 3 task. Low risk — documentation exists.
- **Waybar state query mechanism:** Architecture research notes the voxtype state API mechanism as "TBD (socket file, process presence, or voxtype status subcommand)." Confirm `voxtype status` output format before writing Phase 5 task.
- **Upstream bug #253 resolution status:** Bug was open at research time, assigned to milestone 0.6.4. By the time Phase 2 is executed, check whether 0.6.4 ships the fix — if so, the PATH workaround can be omitted.
- **vigilant GPU performance:** The Surface Laptop 4's AMD integrated GPU (Ryzen 5 4600U iGPU) may or may not give meaningful speedup over CPU for `large-v3-turbo`. If Vulkan shows no benefit, revert vigilant to `packages.default` to avoid the GPU selection bug risk (#273).

## Sources

### Primary (HIGH confidence)
- github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings — no key-release bind in niri; confirmed
- nixos-dotfiles repo — direct inspection of flake.nix, hosts/common/configuration.nix, config/niri/config.kdl, packages/waystt/default.nix
- github.com/peteonrails/voxtype/blob/main/nix/home-manager-module.nix — module option structure
- github.com/peteonrails/voxtype/blob/main/nix/nixos-module.nix — system-level module scope

### Secondary (MEDIUM confidence)
- github.com/peteonrails/voxtype — README, flake.nix outputs, CONFIGURATION.md
- voxtype.io/news — v0.6.3 and v0.6.4 release notes
- github.com/peteonrails/voxtype/issues/253 — service PATH bug, open March 2026
- github.com/peteonrails/voxtype/issues/273 — Vulkan GPU selection bug, open March 2026
- northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2026-benchmarks — Whisper bilingual accuracy
- discourse.nixos.org — nixpkgs.follows pattern and consequences
- nixos.wiki/wiki/Overlays — overlay list merging behavior

---
*Research completed: 2026-03-20*
*Ready for roadmap: yes*
