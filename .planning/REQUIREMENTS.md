# Requirements: Romey NixOS — Voxtype Integration

**Defined:** 2026-03-20
**Core Value:** Maintain a reproducible, modular NixOS configuration that works reliably across all three hosts

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Flake Integration

- [ ] **FLAKE-01**: Voxtype flake input added to flake.nix with nixpkgs.follows to avoid double evaluation
- [ ] **FLAKE-02**: Voxtype nixosModule imported in common configuration.nix
- [ ] **FLAKE-03**: Voxtype homeManagerModule imported in common home.nix

### Speech-to-Text Core

- [ ] **STT-01**: Voxtype daemon running as systemd user service on all three hosts
- [ ] **STT-02**: Whisper base.en model configured for transcription
- [ ] **STT-03**: Text injection at cursor working via wtype/ydotool
- [ ] **STT-04**: Service PATH workaround applied for upstream bug #253

### Push-to-Talk

- [ ] **PTT-01**: Push-to-talk working via voxtype's built-in evdev hotkey mode
- [ ] **PTT-02**: Hotkey configured as Alt_R + Menu combo
- [ ] **PTT-03**: Voxtype hotkey uses evdev (not compositor bindings, since Niri lacks key-release)

### GPU Acceleration

- [ ] **GPU-01**: Vulkan package variant used on intrepid (AMD desktop)
- [ ] **GPU-02**: Vulkan package variant used on vigilant (AMD Surface Laptop)
- [ ] **GPU-03**: CPU-only (default) package variant used on mischief (Intel)

### waystt Removal

- [ ] **REM-01**: Waystt overlay removed from flake.nix
- [ ] **REM-02**: Waystt package directory (packages/waystt/) removed
- [ ] **REM-03**: Waystt-related Niri keybindings removed from config
- [ ] **REM-04**: Waystt toggle/status scripts removed or replaced

### Waybar Integration

- [ ] **BAR-01**: Waybar STT status script updated to query voxtype state
- [ ] **BAR-02**: Waybar module shows recording/idle status for voxtype

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
| FLAKE-01 | — | Pending |
| FLAKE-02 | — | Pending |
| FLAKE-03 | — | Pending |
| STT-01 | — | Pending |
| STT-02 | — | Pending |
| STT-03 | — | Pending |
| STT-04 | — | Pending |
| PTT-01 | — | Pending |
| PTT-02 | — | Pending |
| PTT-03 | — | Pending |
| GPU-01 | — | Pending |
| GPU-02 | — | Pending |
| GPU-03 | — | Pending |
| REM-01 | — | Pending |
| REM-02 | — | Pending |
| REM-03 | — | Pending |
| REM-04 | — | Pending |
| BAR-01 | — | Pending |
| BAR-02 | — | Pending |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 0
- Unmapped: 19

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after initial definition*
