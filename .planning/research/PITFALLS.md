# Pitfalls Research

**Domain:** NixOS flake-based multi-host dotfiles — speech-to-text integration (voxtype, replacing waystt)
**Researched:** 2026-03-20
**Confidence:** HIGH for pitfalls sourced from direct issue tracker inspection and official docs; MEDIUM for pitfalls sourced from community patterns; noted per pitfall

---

## Critical Pitfalls

### Pitfall 1: Niri Has No Key-Release Bind — Push-to-Talk Requires Evdev Mode

**What goes wrong:**
The niri compositor has no `on-release`, `bindr`, or equivalent mechanism to trigger an action when a key is released. Attempting to implement push-to-talk in niri using "hold key = record, release key = stop" via compositor bindings will fail silently — the stop command never fires on key-up.

**Why it happens:**
Users migrating from Sway or Hyprland (which have `bindr` / `--release` flags) assume niri has equivalent functionality. The ARCHITECTURE.md in this repo contains a speculative `release=true` bind syntax example that is unverified and likely incorrect. Niri's documented bind flags are: `repeat`, `cooldown-ms`, `allow-when-locked`, `hotkey-overlay-title`, `write-to-disk`, `show-pointer`, `allow-inhibiting`. None trigger on key release.

**How to avoid:**
Do NOT use `hotkey.enabled = false` in voxtype's config when running on niri. Instead, keep voxtype's built-in evdev hotkey listener active (`hotkey.enabled` defaults to `true`). Configure the push-to-talk key in `~/.config/voxtype/config.toml` under `[hotkey]`. The user (`dustin`) is already in the `input` extraGroup in `hosts/common/configuration.nix` — evdev mode works without any additional system changes.

If compositor-driven toggle (not hold-to-talk) is acceptable, use `repeat=false` on a single bind and have the bind call `voxtype record start` on odd presses and `voxtype record stop` on even presses via a toggle script. This is not true push-to-talk.

**Warning signs:**
- Niri bind config has two lines for the same key (one for start, one "release=true" for stop)
- After pressing the key, transcription continues indefinitely and never stops
- The `voxtype record stop` command only fires when you press the key again, not when you release it

**Phase to address:** Flake + NixOS module integration phase — decide push-to-talk approach before writing any niri bind config

---

### Pitfall 2: Home Manager Service Cannot Find Runtime Dependencies (Open Bug #253)

**What goes wrong:**
When `programs.voxtype.service.enable = true`, the voxtype systemd user service starts but fails to inject text. Error: `"All output methods failed. Ensure wtype, dotool, ydotool, wl-copy, or xclip is available."` Running `voxtype` manually from a terminal works fine.

**Why it happens:**
The systemd user service unit launched by the home-manager module does not inherit the user's PATH. The wrapped voxtype package bundles wtype and other tools in its own Nix store path, but the service's `ExecStart` does not reference the wrapper's internal PATH correctly. This is a confirmed open bug assigned to voxtype milestone 0.6.4 (issue #253, opened March 6, 2026). It is NOT resolved in 0.6.3.

**How to avoid:**
If deploying with `service.enable = true`, add a PATH override to the service unit to ensure the Nix profile bins are found:

```nix
config.systemd.user.services.voxtype = {
  Service.Environment = [ "PATH=/run/current-system/sw/bin:${config.home.profileDirectory}/bin" ];
};
```

Alternatively, watch for the 0.6.4 release which is supposed to fix this. Verify the fix by checking `systemctl --user status voxtype` and attempting a transcription after deployment.

**Warning signs:**
- `systemctl --user status voxtype` shows no errors, but text never appears after speaking
- `journalctl --user -u voxtype` shows "All output methods failed" error
- Manual `voxtype` in a terminal works correctly

**Phase to address:** Home Manager module integration phase — add the workaround before first deployment and note it is a known upstream bug

---

### Pitfall 3: voxtype Flake Uses nixpkgs-unstable — Must Force nixpkgs.follows

**What goes wrong:**
The voxtype flake.nix declares `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`. If `voxtype.inputs.nixpkgs.follows = "nixpkgs"` is NOT added in `flake.nix`, Nix will evaluate voxtype against `nixos-unstable` while the rest of the system uses `nixos-25.05`. This creates two nixpkgs instances, doubles evaluation time and disk usage, and can produce subtle ABI or linking incompatibilities.

**Why it happens:**
Flake inputs do not automatically inherit the consuming flake's nixpkgs. Without explicit `follows`, each input brings its own pinned nixpkgs instance. The repo already uses this pattern correctly for other inputs (`home-manager`, `sops-nix`, `fresh`, `claude-code`) — voxtype must be added to that list.

**How to avoid:**
Add the `follows` line in `flake.nix`:
```nix
voxtype.url = "github:peteonrails/voxtype";
voxtype.inputs.nixpkgs.follows = "nixpkgs";
```

**Warning signs:**
- `nix flake show` lists the voxtype input without a `nixpkgs` follow annotation
- `nix flake metadata` shows two different nixpkgs revisions in use
- Build times increase substantially after adding voxtype
- `nix path-info` shows duplicate nixpkgs store paths

**Phase to address:** flake.nix input wiring (first step of implementation)

---

### Pitfall 4: Waystt Overlay Conflicts with voxtype if Not Fully Removed

**What goes wrong:**
The existing flake has a custom overlay that adds `waystt` to `pkgs`:
```nix
overlay = final: prev: { waystt = final.callPackage ./packages/waystt { }; };
```
This overlay is applied globally via `nixpkgs.overlays = [ overlay ]` inside `mkHost`. If voxtype is added but waystt is not cleanly removed, both STT tools compete: two keybindings fire, `pkill waystt` in old scripts finds no process, and the waystt overlay still gets evaluated even though nothing uses it — wasting build time and adding Vulkan compile dependencies to every host including mischief.

**Why it happens:**
Incremental migrations often leave old code in place to "fall back to." In NixOS, unused overlays are still evaluated. The `packages/waystt/default.nix` derivation has complex Vulkan/clang build requirements that will fail or silently degrade on hosts without Vulkan headers (or if LLVM version shifts).

**How to avoid:**
Remove all waystt references atomically in one commit:
1. `flake.nix`: Delete the `overlay` let binding, the `waystt = final.callPackage ...` line, and `nixpkgs.overlays = [ overlay ]` from mkHost
2. `packages/waystt/default.nix`: Delete the entire `packages/waystt/` directory
3. `hosts/common/configuration.nix`: Remove `waystt` from `environment.systemPackages`
4. `config/niri/config.kdl`: Remove Mod+R / Mod+Shift+R waystt bindings
5. `bin/stt-toggle.sh`: Delete or replace with voxtype commands

**Warning signs:**
- `nix flake check` still processes the waystt derivation after "removal"
- Both `waystt` and `voxtype` appear in `nix-env -q` or `nix store path`
- Both Mod+R bindings exist in niri config

**Phase to address:** waystt removal — do this in the same phase as voxtype activation, not before or after

---

## Moderate Pitfalls

### Pitfall 5: vulkan Package on mischief (Intel HD 520) — Silent Failure or Slowdown

**What goes wrong:**
Setting `programs.voxtype.package = inputs.voxtype.packages.${system}.vulkan` in common home.nix causes the Vulkan build to run on mischief. Intel HD 520 (Gen 9, 2016) has Vulkan drivers but they are inadequate for neural network inference workloads. The build may succeed but voxtype will either fall back to CPU (silently slower) or crash at inference time.

There is a confirmed related bug: voxtype issue #273 (opened March 20, 2026) reports "v0.6.4 utilizes integrated Intel iGPU alongside dedicated Nvidia GPU, causing slowdown" — showing that GPU selection logic can pick the wrong GPU when multiple are present.

**Prevention:**
Set `programs.voxtype.package` to `default` (CPU) in common home.nix. Only override to `vulkan` in `hosts/intrepid/home.nix` and `hosts/vigilant/home.nix`. This is the existing per-host override pattern already established in this repo.

**Warning signs:**
- Transcription on mischief is slower than expected
- `journalctl --user -u voxtype` shows Vulkan initialization failures or warnings
- `voxtype status` reports an unexpected GPU backend

**Phase to address:** Per-host package variant phase — explicitly set default to CPU and verify before setting Vulkan on AMD hosts

---

### Pitfall 6: Model Download Happens at nixos-rebuild Time, Not at Runtime

**What goes wrong:**
When `programs.voxtype.model.name = "base.en"` is set in the home-manager module, the model is downloaded from HuggingFace during `nixos-rebuild switch` as a fixed-output derivation. If the build machine has no internet access, or if HuggingFace is slow/rate-limited, the rebuild will fail with a fetch error.

**Prevention:**
Either ensure internet access during the first rebuild on each host, or pre-download the model file and use `model.path` pointing to a local path instead of `model.name`. The local path approach works even with no internet.

As an alternative, defer model configuration until after the basic daemon is working: first deploy with `service.enable = true` but no `model.name` set, manually run `voxtype setup --download` once, then add `model.name` in a subsequent rebuild.

**Warning signs:**
- `nixos-rebuild switch` hangs or fails with a network fetch error
- Error message contains `HuggingFace` or the model URL
- The build error is a fixed-output derivation hash mismatch

**Phase to address:** Home Manager module integration — document the internet dependency in the phase task so it is not a surprise

---

### Pitfall 7: Overlays in nixpkgs.overlays Set in Multiple Places Silently Overwrite

**What goes wrong:**
The current flake has TWO places where `nixpkgs.overlays` is set:
1. Inside `mkHost`: `nixpkgs.overlays = [ overlay ]` (for waystt)
2. Inside `hosts/common/configuration.nix`: `nixpkgs.overlays = [ inputs.claude-code.overlays.default ]` (for claude-code)

NixOS merges list options from multiple modules, so both overlays apply. However, if the waystt overlay is removed incorrectly (e.g., the list assignment in `configuration.nix` is replaced with an empty list rather than just removing the waystt entry), the claude-code overlay is silently dropped. This would break the `claude-code` package in `home.packages`.

**Prevention:**
When removing the waystt overlay from `flake.nix` `mkHost`, only delete the `waystt = ...` entry from the overlay function — or delete the entire overlay variable if waystt is the only entry. Verify `claude-code` is still present in `nix shell` after the rebuild.

**Warning signs:**
- `claude-code` command not found after the rebuild
- `home.packages` evaluation error about missing `claude-code` package

**Phase to address:** waystt removal phase — audit overlay list before and after

---

### Pitfall 8: base.en Model Is Whisper-Only — ONNX Engine Assertion Will Fail

**What goes wrong:**
The home-manager module enforces an assertion: `model.name` and `model.path` cannot both be set, AND ONNX engines (`parakeet`, `moonshine`, `sensevoice`, etc.) cannot use `model.name`. If the engine is later changed to an ONNX engine (e.g., experimenting with Moonshine for speed) while `model.name = "base.en"` remains, the assertion fires at `nixos-rebuild switch` time with a cryptic error.

**Prevention:**
Keep `engine = "whisper"` (the default) whenever using `model.name`. If experimenting with ONNX engines, switch to `model.path` pointing to a downloaded model directory and remove `model.name`.

**Warning signs:**
- `nixos-rebuild switch` fails with an assertion error about model configuration
- Error mentions that `model.name` is incompatible with the selected engine

**Phase to address:** Home Manager module integration — document the engine/model constraint in the phase task

---

## Minor Pitfalls

### Pitfall 9: stt-toggle.sh Script Left in bin/ After Migration

**What goes wrong:**
The existing `bin/stt-toggle.sh` script is symlinked to `~/.local/bin/stt-toggle.sh` via home-manager. After migrating to voxtype, this script still exists and still calls `waystt --pipe-to ...` which no longer works. If the niri binding is updated to call `voxtype record start/stop` but the old script remains, confusion arises about which approach is active.

**Prevention:**
Delete or replace `bin/stt-toggle.sh` in the same commit that updates the niri keybindings. If a wrapper script is still desired (e.g., to add notifications), rewrite it to call `voxtype record start` / `voxtype record stop`.

**Warning signs:**
- `~/.local/bin/stt-toggle.sh` still references `waystt`
- `stt-toggle.sh` produces "command not found: waystt" when called

**Phase to address:** Niri keybinding / cleanup phase

---

### Pitfall 10: ydotool Service May Conflict with voxtype nixosModule Assertion

**What goes wrong:**
`hosts/common/configuration.nix` already has `programs.ydotool.enable = true`. The voxtype `nixosModules.default` may also try to set this same option. NixOS module option merging handles this correctly for boolean options (both `true` = `true`), but if voxtype's nixosModule uses `lib.mkDefault` and the common config uses a plain `= true`, or vice versa, there may be a conflict warning or unexpected behavior.

**Prevention:**
After importing `inputs.voxtype.nixosModules.default`, verify via `nix eval .#nixosConfigurations.mischief.config.programs.ydotool.enable` that the option is still `true`. If there is a conflict, use `lib.mkForce true` to be explicit in `common/configuration.nix`.

**Warning signs:**
- `nixos-rebuild switch` prints a warning about `programs.ydotool.enable` being set in multiple places
- ydotool daemon fails to start after the rebuild

**Phase to address:** NixOS module integration — verify ydotool option after importing the module

---

### Pitfall 11: Waybar stt-status.sh Script Polls waystt Process Name

**What goes wrong:**
The waybar status widget script (referenced in niri config at `config/waybar/`) polls for the `waystt` process by name to determine recording state. After removing waystt and deploying voxtype, the widget will always show "not recording" even when voxtype is active. The script must be updated to query voxtype's state instead.

**Prevention:**
Update the status script before or alongside the keybinding changes. Check whether voxtype exposes a `voxtype status` subcommand, a socket file, or a process name that can be polled. Based on voxtype docs, `voxtype status` is available as a subcommand.

**Warning signs:**
- Waybar STT widget always shows idle/not-recording icon
- The script still contains `pgrep waystt` or references to waystt

**Phase to address:** Waybar integration phase (can be deferred — cosmetic, not functional)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Leave `bin/stt-toggle.sh` but update niri config | Skip one file deletion | Confusing dead code; script fails if called accidentally | Never — delete it |
| Set `voxtype.inputs.nixpkgs.follows` to `nixpkgs` but not verify with `nix flake metadata` | Saves one verification step | Double nixpkgs evaluation; slower builds; subtle ABI issues | Never — verify |
| Use `model.path` pointing to a manually downloaded file instead of declarative `model.name` | Avoids HuggingFace fetch during rebuild | Model not in Nix store; not reproducible; path may differ per host | Acceptable as temporary bootstrap |
| Keep `hotkey.enabled = false` and use a toggle script instead of hold-to-talk | Reuses existing toggle script pattern | Not true push-to-talk; transcription may run unbounded if user forgets to toggle off | Acceptable if hold-to-talk is not needed |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| voxtype flake input | Not setting `voxtype.inputs.nixpkgs.follows = "nixpkgs"` | Always add the `follows` line; the voxtype flake defaults to nixpkgs-unstable |
| Home Manager module import | Importing `homeManagerModules.default` without also importing `nixosModules.default` | Import both; nixosModule handles system deps, homeManagerModule handles user service |
| Per-host package override | Setting `package = inputs.voxtype.packages.x86_64-linux.vulkan` (hardcoded arch) | Use `inputs.voxtype.packages.${pkgs.system}.vulkan` so it works on future aarch64 hosts |
| Niri push-to-talk | Expecting `release=true` bind flag to trigger on key-up | Niri has no key-release bind; use evdev mode (voxtype's built-in hotkey) for hold-to-talk |
| voxtype systemd user service | Deploying `service.enable = true` without the PATH workaround | Apply the `Environment = [...]` workaround until upstream bug #253 is fixed in 0.6.4 |
| waystt overlay removal | Removing only the `waystt` from `environment.systemPackages` but leaving the overlay in `flake.nix` | Remove the overlay variable, its application in `mkHost`, and the `packages/waystt/` directory in one commit |

---

## "Looks Done But Isn't" Checklist

- [ ] **voxtype flake input:** Verify `voxtype.inputs.nixpkgs.follows = "nixpkgs"` is in `flake.nix` — check `nix flake metadata` shows only one nixpkgs instance
- [ ] **waystt removal:** Verify `packages/waystt/` directory is gone, overlay is removed from `flake.nix`, and `waystt` is not in `environment.systemPackages`
- [ ] **Daemon running:** Verify `systemctl --user status voxtype` shows `active (running)` on each host after deployment
- [ ] **Text injection works:** Test a transcription by speaking after pressing the hotkey — confirm text appears at cursor (not just in clipboard)
- [ ] **Vulkan on AMD:** On intrepid/vigilant, verify `voxtype status` shows the Vulkan backend is active, not CPU fallback
- [ ] **CPU on mischief:** On mischief, verify the CPU (default) package is used and inference completes in reasonable time
- [ ] **Hotkey mode:** Verify voxtype is using evdev hotkey mode on niri hosts — the hold-to-talk key should stop recording on release
- [ ] **Service PATH bug:** Verify text injection works when triggered via the hotkey while voxtype runs as a systemd service (not just manual daemon start)
- [ ] **Bilingual detection:** Speak a short Spanish phrase — verify it is transcribed in Spanish, not garbled Romance-language output
- [ ] **Waybar widget:** Verify the STT status widget updates correctly during and after recording

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Niri key-release bind fails | LOW | Change niri config to use evdev hotkey; rebuild niri config (live reload) |
| Service PATH bug blocks text injection | LOW | Add the `Environment` PATH workaround to `systemd.user.services.voxtype`; rebuild home-manager |
| Double nixpkgs from missing `follows` | LOW | Add `voxtype.inputs.nixpkgs.follows = "nixpkgs"`; run `nix flake update`; rebuild |
| waystt partially removed (overlay left) | MEDIUM | Complete the removal checklist; rebuild; verify `nix flake check` passes |
| vulkan package on mischief causes failure | LOW | Override `programs.voxtype.package` to `default` in a per-host home.nix; rebuild mischief |
| Model download fails during rebuild | MEDIUM | Pre-download model manually; set `model.path` instead of `model.name`; rebuild |
| ONNX assertion error from engine/model mismatch | LOW | Remove `model.name` or set `engine = "whisper"` to match; rebuild |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Niri has no key-release bind | Phase 1 (flake/integration planning) | Confirm push-to-talk approach before writing any niri config |
| Service PATH bug (#253) | Phase 2 (Home Manager module integration) | Test text injection via service after first deployment |
| Missing nixpkgs.follows | Phase 1 (flake.nix input wiring) | `nix flake metadata` shows single nixpkgs; build time is reasonable |
| waystt overlay conflicts | Phase 3 (waystt removal) | `nix flake check` passes; `packages/waystt/` directory is gone |
| vulkan on mischief | Phase 2 or 4 (per-host variant) | `voxtype status` on mischief shows CPU backend |
| Model download at build time | Phase 2 (Home Manager module) | Document internet requirement; first rebuild on each host must have network access |
| base.en + ONNX engine assertion | Phase 2 (Home Manager module) | `nixos-rebuild switch` passes without assertion errors |
| stt-toggle.sh dead code | Phase 3 or 4 (cleanup) | `bin/stt-toggle.sh` either deleted or updated to voxtype commands |
| ydotool option conflict | Phase 1 (NixOS module import) | `nix eval` confirms `programs.ydotool.enable = true` after module import |
| Waybar script polls waystt | Phase 5 (Waybar integration) | Widget updates state correctly; no references to waystt in scripts |

---

## Sources

- [github.com/peteonrails/voxtype/issues/253](https://github.com/peteonrails/voxtype/issues/253) — Home Manager service PATH bug, confirmed open March 2026, milestone 0.6.4 (MEDIUM confidence — GitHub issue, not official documentation)
- [github.com/peteonrails/voxtype/blob/main/nix/home-manager-module.nix](https://github.com/peteonrails/voxtype/blob/main/nix/home-manager-module.nix) — engine/model assertion behavior confirmed (MEDIUM confidence — source inspection)
- [github.com/peteonrails/voxtype/blob/main/flake.nix](https://github.com/peteonrails/voxtype/blob/main/flake.nix) — nixpkgs-unstable default confirmed; package variant names confirmed (MEDIUM confidence)
- [github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings) — no on-release bind flag in niri documented (HIGH confidence — official niri wiki)
- [niri-wm.github.io/niri/Configuration:-Key-Bindings.html](https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html) — corroborates no key-release bind (MEDIUM confidence)
- [github.com/peteonrails/voxtype/issues](https://github.com/peteonrails/voxtype/issues) — Vulkan GPU selection bug #273, open March 20, 2026 (MEDIUM confidence)
- [discourse.nixos.org — Home Manager and Nixpkgs Version Mismatch](https://discourse.nixos.org/t/home-manager-and-nixpkgs-version-mismatch/60331) — nixpkgs.follows pattern and consequences (MEDIUM confidence)
- [nixos.wiki/wiki/Overlays](https://nixos.wiki/wiki/Overlays) — overlay list merging behavior (HIGH confidence — official wiki)
- Direct repo inspection: `flake.nix`, `hosts/common/configuration.nix`, `config/niri/config.kdl`, `packages/waystt/default.nix`, `bin/stt-toggle.sh` (HIGH confidence)

---
*Pitfalls research for: NixOS voxtype speech-to-text integration (replacing waystt)*
*Researched: 2026-03-20*
