# Requirements: Romey NixOS — Voxtype Integration

**Defined:** 2026-03-20
**Core Value:** Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Flake Integration

- [x] **FLAKE-01**: Voxtype flake input added to flake.nix with nixpkgs.follows to avoid double evaluation
- [x] **FLAKE-02**: Voxtype nixosModule imported in common configuration.nix
- [x] **FLAKE-03**: Voxtype homeManagerModule imported in common home.nix

### Speech-to-Text Core

- [x] **STT-01**: Voxtype daemon running as systemd user service on all three hosts
- [x] **STT-02**: Whisper base.en model configured for transcription
- [x] **STT-03**: Text injection at cursor working via wtype/ydotool
- [x] **STT-04**: Service PATH workaround applied for upstream bug #253

### Push-to-Talk

- [x] **PTT-01**: Push-to-talk working via voxtype's built-in evdev hotkey mode
- [x] **PTT-02**: Hotkey configured as Alt_R + Menu combo
- [x] **PTT-03**: Voxtype hotkey uses evdev (not compositor bindings, since Niri lacks key-release)

### GPU Acceleration

- [x] **GPU-01**: Vulkan package variant used on intrepid (AMD desktop)
- [x] **GPU-02**: Vulkan package variant used on vigilant (AMD Surface Laptop)
- [x] **GPU-03**: CPU-only (default) package variant used on mischief (Intel)

### waystt Removal

- [x] **REM-01**: Waystt overlay removed from flake.nix
- [x] **REM-02**: Waystt package directory (packages/waystt/) removed
- [x] **REM-03**: Waystt-related Niri keybindings removed from config
- [x] **REM-04**: Waystt toggle/status scripts removed or replaced

### Waybar Integration

- [x] **BAR-01**: Waybar STT status script updated to query voxtype state
- [x] **BAR-02**: Waybar module shows recording/idle status for voxtype

### Claude Integration

- [x] **CLAUDE-01**: Claude Code CLI installed via Nix and available in PATH on all hosts
- [x] **CLAUDE-02**: Claude desktop app installed with desktop entry and icon
- [x] **CLAUDE-03**: Both claude packages added through common home.nix (shared across hosts)
- [x] **CLAUDE-04**: `nix flake check` passes with claude packages present

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Bilingual Support

- **LANG-01**: Switch to large-v3-turbo model for EN/ES bilingual dictation
- **LANG-02**: Word replacements for spoken punctuation (EN/ES conventions)

### Quality of Life

- **QOL-01**: Audio feedback sound cues for record start/stop
- **QOL-02**: Smart auto-submit for chat/messaging workflows

### Advanced

- **ADV-01**: Remote GPU offload (vigilant transcribing on intrepid)
- **ADV-02**: Toggle mode as alternative to push-to-talk
- **ADV-03**: ONNX engine variants for alternative models

## Out of Scope

| Feature | Reason |
|---------|--------|
| Qtile keybindings for voxtype | User is on Niri; Qtile bindings not needed |
| ROCm variant | Vulkan preferred for portability across AMD GPUs |
| CUDA variant | No NVIDIA hardware in any host |
| Niri key-release compositor binds | Niri doesn't support key-release; evdev hotkey used instead |

## Must NOT Do

> Auto-generated from DOMAIN.md. Review and add additional non-behaviors before approving.

- The system must NOT use the Vulkan package variant on mischief because Intel HD 520 (Gen 9) has no usable Vulkan for inference — it would be slower than CPU
- The system must NOT configure push-to-talk via Niri compositor key-release bindings because Niri does not support key-release events — use voxtype's evdev hotkey instead
- The system must NOT leave the waystt overlay in flake.nix when adding voxtype because competing overlays waste build time and risk daemon conflicts
- The system must NOT skip `voxtype.inputs.nixpkgs.follows = "nixpkgs"` because it causes double nixpkgs evaluation

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FLAKE-01 | Phase 1 | Complete |
| FLAKE-02 | Phase 1 | Complete |
| FLAKE-03 | Phase 1 | Complete |
| STT-01 | Phase 2 | Complete |
| STT-02 | Phase 2 | Complete |
| STT-03 | Phase 2 | Complete |
| STT-04 | Phase 2 | Complete |
| PTT-01 | Phase 2 | Complete |
| PTT-02 | Phase 2 | Complete |
| PTT-03 | Phase 2 | Complete |
| REM-01 | Phase 2 | Complete |
| REM-02 | Phase 2 | Complete |
| REM-03 | Phase 2 | Complete |
| REM-04 | Phase 2 | Complete |
| GPU-01 | Phase 3 | Complete |
| GPU-02 | Phase 3 | Complete |
| GPU-03 | Phase 3 | Complete |
| BAR-01 | Phase 3 | Complete |
| BAR-02 | Phase 3 | Complete |

| CLAUDE-01 | Phase 4 | Planned |
| CLAUDE-02 | Phase 4 | Planned |
| CLAUDE-03 | Phase 4 | Planned |
| CLAUDE-04 | Phase 4 | Planned |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after roadmap creation*
