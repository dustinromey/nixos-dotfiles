# Feature Research

**Domain:** Speech-to-text integration for NixOS dotfiles (voxtype, replacing waystt)
**Researched:** 2026-03-20
**Confidence:** MEDIUM-HIGH (voxtype official site + GitHub verified; NixOS integration partially inferred from release notes)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any functional speech-to-text integration must have. Missing these means the tool doesn't work in daily use.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Push-to-talk activation | Core interaction model — hold to record, release to transcribe | LOW | Voxtype supports via compositor keybindings (Niri: `spawn` binds) or evdev fallback. Niri does NOT natively support key-release events like Hyprland/Sway/River, so evdev path will be needed; requires `input` group membership. |
| Text injection at cursor | Core utility — transcribed text must appear where cursor is | LOW | Voxtype uses wtype → dotool → ydotool fallback chain. wtype is best but needs virtual-keyboard protocol support from compositor. Niri compatibility needs verification. |
| Offline operation | Privacy expectation for local dictation; no cloud dependency | LOW | Voxtype uses whisper.cpp locally. This is table stakes because it's the primary reason users choose local tools over cloud APIs. |
| Working audio capture | Must record from microphone reliably | LOW | PipeWire is standard on NixOS. Voxtype works with PipeWire. Audio device selection is TOML-configurable. |
| English language support | User's primary working language | LOW | All whisper models support English well. `tiny.en` or `base.en` gives fast performance for EN-only. |
| NixOS declarative configuration | In a dotfiles repo, config must be expressed in Nix — imperative setup is unacceptable | MEDIUM | Voxtype provides a Home Manager module via its flake. The module merges user settings into defaults (v0.6.3+). This is the whole point of the project: declarative, reproducible. |
| Reproducible across hosts | Same config must work on mischief, intrepid, vigilant without manual steps | MEDIUM | Requires flake input in flake.nix and Home Manager module options that handle per-host GPU differences declaratively. |

### Differentiators (Competitive Advantage)

Features beyond baseline that make the integration genuinely better than the waystt replacement it's replacing.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Spanish (ES) language support | Bilingual EN/ES use requires a multilingual model — not all tools handle this well | LOW | Use `large-v3` or `large-v3-turbo` whisper model. Both handle EN/ES with ~7-8% WER. `large-v3-turbo` is 6x faster with <2% accuracy loss — the right choice for bilingual real-time dictation. Force language with `--language es` when needed, or use auto-detect. |
| Per-host GPU-accelerated inference | intrepid (AMD RX-class) and vigilant (AMD integrated) have different GPU capabilities; mischief (Intel) may only get CPU | MEDIUM | Voxtype ships Vulkan (AMD/Intel/NVIDIA), CUDA, and ROCm variants as separate NixOS packages. Host-specific Home Manager config can select correct variant. AMD RX 6800 achieves ~35x realtime with GPU vs ~7x CPU — significant for larger models. |
| Waybar status indicator | User can see at-a-glance whether voxtype is recording (visual feedback) | LOW | Voxtype writes a state file by default. Waybar reads it with a custom module. Config is a few lines in waybar config. This is a genuine quality-of-life win for a tool used daily. |
| Audio feedback (sound cues) | Confirms recording start/stop without needing to watch the screen | LOW | Voxtype has built-in themes: `default`, `subtle`, `mechanical`. Enable in TOML. Zero implementation cost. |
| Word replacements / spoken punctuation | Dictate "period" → types `.` — makes dictation flow more naturally | LOW | Voxtype supports word replacement rules in TOML config. Useful for establishing EN/ES punctuation conventions. |
| Smart auto-submit | Say "submit" or "send" at end of dictation to automatically press Enter | LOW | Added in v0.6.4. Reduces friction for chat/messaging workflows. Config option in TOML. |
| Toggle mode (alternative to hold) | Some workflows prefer press-once-to-start, press-once-to-stop rather than hold | LOW | Voxtype supports both modes. Toggle mode is better for longer dictations where holding a key is fatiguing. |
| Remote GPU offload | Transcribe on a more powerful machine (e.g., desktop) while dictating on laptop | HIGH | Voxtype supports offloading to self-hosted whisper.cpp server. Useful for vigilant (Surface Laptop, lower GPU) leveraging intrepid (desktop AMD). Requires network config and server setup — defer unless CPU/local GPU is too slow. |
| Clipboard restoration in paste mode | When using paste-mode output, clipboard is restored after paste | LOW | Added in v0.6.3. Prevents voxtype from clobbering whatever was in clipboard. Works on Wayland (wl-paste/wl-copy) and X11. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Always-on listening / wake word | "Hands-free" activation feels convenient | Privacy-invasive, high CPU load from continuous inference, accidental activations, security concern on shared machines. Not how whisper.cpp is designed to operate. | Push-to-talk is the right model: intentional, zero idle CPU, no false activations. |
| Cloud transcription fallback | "Use cloud when local model is slow" | Introduces privacy leak, network dependency, cost, and latency variance. Voxtype is specifically chosen to be offline-first. | Use a faster local model: `large-v3-turbo` on GPU, `base.en` on CPU for speed-critical paths. |
| Meeting mode for daily use | Meeting mode exists in voxtype (v0.6.0) | It's a separate workflow (continuous transcription with speaker attribution, export to SRT/VTT). Building Home Manager config around it adds complexity for no benefit in a push-to-talk dotfiles integration. | Enable meeting mode manually when actually in a meeting. Don't configure it as default. |
| Custom STT engine beyond Whisper | "Support all 7 voxtype engines" | ONNX engines (Parakeet, Moonshine, Dolphin, etc.) require ONNX binary variant (larger, different package). Most are English-only or specialized (Paraformer = Chinese+English). Adds packaging complexity for minimal gain. | Stick with Whisper engine (the default) using `large-v3-turbo` for EN/ES bilingual use. Add ONNX variant only if Whisper accuracy proves insufficient. |
| Per-application text injection tuning | "Use ydotool for app X, wtype for app Y" | wtype handles Wayland apps natively; the fallback chain already handles this automatically. Manual per-app config is fragile and compositor-specific. | Trust voxtype's built-in fallback chain: wtype → dotool → ydotool. Only intervene if a specific app is broken. |
| Automatic language detection per-utterance | "Auto-switch EN/ES mid-dictation" | Whisper auto-detect works on utterance level but can misfire on short phrases. Switching language mid-sentence produces unreliable output. | Configure language explicitly per session (EN or ES). Use toggle binding to switch language via voxtype config reload, or accept slight accuracy hit from auto-detect on `large-v3`. |

---

## Feature Dependencies

```
[NixOS flake input (voxtype)]
    └──required by──> [Home Manager module]
                          └──required by──> [Per-host configuration]
                          └──required by──> [GPU variant selection]
                          └──required by──> [Waybar state file path]

[Whisper model download]
    └──required by──> [Any transcription]
                          └──required by──> [English support]
                          └──required by──> [Spanish support]

[Compositor keybinding OR evdev group membership]
    └──required by──> [Push-to-talk activation]
                          └──required by──> [Text injection at cursor]

[Push-to-talk activation]
    └──enhances──> [Audio feedback (sound cues)]
    └──enhances──> [Waybar status indicator]

[Per-host GPU variant] ──conflicts with──> [Single shared Home Manager config]
    (requires host-specific override or conditional selection)

[large-v3-turbo model] ──enables──> [Spanish support at acceptable speed]
    (tiny.en / base.en are English-only; large-v3 is too slow on CPU for real-time)

[Niri compositor]
    └──NOTE: Does not support key-release events natively]
    └──therefore──> [evdev hotkey required for push-to-talk on Niri]
    └──therefore──> [input group membership required on Niri hosts]
```

### Dependency Notes

- **Flake input requires Home Manager module:** The voxtype flake must be added as an input to `flake.nix` before any Home Manager module can reference it. This is Phase 1 work.
- **GPU variant selection requires per-host config:** intrepid needs the Vulkan/ROCm package; mischief (Intel) may use CPU-only. These must be expressed as host overrides in `hosts/<hostname>/home.nix`, not in `hosts/common/home.nix`.
- **Waybar state file requires known path:** The Waybar module config must reference the same path that voxtype's `state_file` option writes to. These must be kept in sync — a single source of truth in the Nix config is the right approach.
- **Niri push-to-talk requires evdev, not compositor keybindings:** Unlike Hyprland/Sway/River, Niri does not expose key-release events for arbitrary keybinds, so voxtype's compositor-native push-to-talk cannot be used. The evdev fallback works but requires the user to be in the `input` group. This is a NixOS system-level config change, not just a Home Manager change.
- **Spanish requires large-v3 or large-v3-turbo:** The smaller English-optimized models (`tiny.en`, `base.en`, `small.en`) do not support Spanish. If the user is bilingual and switches languages, a multilingual model is required. `large-v3-turbo` is the recommended choice: ~6x faster than full large-v3 with <2% accuracy degradation.

---

## MVP Definition

### Launch With (v1)

Minimum viable integration — voxtype works for daily EN/ES dictation on all three hosts, declaratively configured.

- [ ] Flake input added to `flake.nix` — prerequisite for everything
- [ ] Home Manager module enabled in `hosts/common/home.nix` — base config shared across hosts
- [ ] `input` group membership configured for all hosts — required for evdev push-to-talk on Niri
- [ ] Push-to-talk keybinding in Niri config — binds to voxtype record start/stop
- [ ] `large-v3-turbo` whisper model selected — handles EN/ES at acceptable speed
- [ ] Text injection via wtype (with fallback chain) — types at cursor in Wayland apps
- [ ] Waybar status indicator — visual feedback that recording is active

### Add After Validation (v1.x)

Features to add once core is confirmed working daily.

- [ ] Per-host GPU variant selection — enable Vulkan acceleration on intrepid; CPU-only on mischief; test vigilant (AMD integrated)
- [ ] Audio feedback sound cues — enable after confirming push-to-talk flow feels right
- [ ] Word replacements for punctuation — "period", "comma", etc. in EN and ES
- [ ] Smart auto-submit — enable once dictation patterns are established

### Future Consideration (v2+)

Features to defer until the core integration is stable.

- [ ] Remote GPU offload (vigilant → intrepid) — only if vigilant GPU performance is insufficient for real-time dictation
- [ ] Toggle mode as alternative to push-to-talk — only if push-to-talk proves fatiguing for long-form dictation
- [ ] ONNX engine variants — only if Whisper accuracy on ES proves insufficient

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Flake input + Home Manager module | HIGH | LOW | P1 |
| Push-to-talk on Niri (evdev) | HIGH | LOW | P1 |
| input group membership | HIGH | LOW | P1 |
| large-v3-turbo model (EN/ES) | HIGH | LOW | P1 |
| Text injection at cursor | HIGH | LOW | P1 |
| Waybar status indicator | MEDIUM | LOW | P1 |
| Per-host GPU variant | HIGH | MEDIUM | P2 |
| Audio feedback | LOW | LOW | P2 |
| Word replacements | MEDIUM | LOW | P2 |
| Smart auto-submit | LOW | LOW | P2 |
| Remote GPU offload | MEDIUM | HIGH | P3 |
| Toggle mode | LOW | LOW | P3 |
| ONNX engines | LOW | MEDIUM | P3 |
| Meeting mode | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | waystt (replaced) | nerd-dictation | voxtype |
|---------|-------------------|----------------|---------|
| Wayland text injection | ydotool only | ydotool only | wtype → dotool → ydotool (best CJK/Unicode) |
| Push-to-talk | SIGUSR1 signal | N/A (X11 focus) | Compositor keybinds or evdev |
| Spanish support | Yes (any Whisper model) | Yes (Python + Whisper) | Yes (large-v3-turbo recommended) |
| NixOS flake + HM module | No official module | No official module | Yes, maintained (v0.6.3+) |
| GPU acceleration | Not documented | No | Vulkan, CUDA, ROCm |
| Waybar integration | No | No | Yes (state file) |
| Offline operation | Yes (local Whisper) | Yes (local Whisper) | Yes (whisper.cpp) |
| Audio feedback | No | No | Yes (built-in themes) |
| Single binary | Yes (Rust) | No (Python) | Yes (Rust) |
| Niri compatibility | Likely (SIGUSR1 works anywhere) | No | Needs evdev path (not compositor keybindings) |

**Key insight for Niri hosts:** waystt's SIGUSR1 model actually works well with Niri because any keybinding can `spawn "kill -SIGUSR1 $(pgrep waystt)"` — no key-release events needed. Voxtype on Niri requires evdev, which needs `input` group. This is the main migration friction: it's a solvable system config change, not a blocker.

---

## Sources

- Voxtype official site and comparison page: https://voxtype.io/compare/ (MEDIUM confidence — vendor-authored)
- Voxtype GitHub repository: https://github.com/peteonrails/voxtype (HIGH confidence — primary source)
- Voxtype FAQ: https://github.com/peteonrails/voxtype/blob/main/docs/FAQ.md (HIGH confidence)
- Voxtype release notes (v0.6.3, v0.6.4): https://voxtype.io/news/ (HIGH confidence — dated 2026-03-19)
- waystt GitHub: https://github.com/sevos/waystt (HIGH confidence)
- Niri keybinding docs: https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings (HIGH confidence)
- Whisper bilingual accuracy benchmarks: https://northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2026-benchmarks (MEDIUM confidence)
- NixOS voxtype packaging notes: inferred from v0.6.3 release notes mentioning `@digunix` and `@DuskyElf` as NixOS packaging owners (MEDIUM confidence)

---
*Feature research for: NixOS speech-to-text integration (voxtype replacing waystt)*
*Researched: 2026-03-20*
