# Codebase Concerns

**Analysis Date:** 2026-03-20

## Tech Debt

**Hardware Configuration Placeholders:**
- Issue: `intrepid` and `vigilant` have placeholder hardware configurations generated at setup time, not from actual hardware scans
- Files: `hosts/intrepid/hardware-configuration.nix`, `hosts/vigilant/hardware-configuration.nix`
- Impact: May miss critical hardware features; UUID-based mount points won't match actual hardware once deployed
- Fix approach: After NixOS installation on each host, run `nixos-generate-config --show-hardware-config` and commit actual hardware configuration. The placeholders were created with generic values and need real hardware detection.

**Color Picker Feature Incomplete:**
- Issue: Niri color picker keybind commented out with TODO; hyprpicker not installed
- Files: `config/niri/config.kdl` (line 189-190)
- Impact: `MOD+PRINT` color picker functionality unavailable
- Fix approach: Either install hyprpicker in `hosts/common/home.nix` or substitute with alternative like `wl-color-picker`, then uncomment keybind in niri config

**Speech-to-Text STT Keybinds Status:**
- Issue: STT (speech-to-text) keybinds are functional but implementation notes mention todo/placeholder status
- Files: `waystt-nixos-prd.md` (line 68 shows hash placeholder), `prompts/completed/007-finish-niri-setup.md`
- Impact: waystt package hash needs verification; STT feature should be tested end-to-end
- Fix approach: Verify waystt package builds correctly by running `nix flake check` on a host and test STT recording via `MOD+R`/`MOD+SHIFT+R` keybinds

## Known Limitations

**Home-Manager Configuration Warning:**
- Issue: flake.nix uses `useGlobalPkgs = true` with `useUserPackages = true` simultaneously
- Files: `flake.nix` (lines 48-49)
- Impact: This configuration is not explicitly recommended in home-manager docs; potential for package conflicts or unexpected behavior with duplicated packages
- Current behavior: System packages (from `nixosConfiguration`) are reused by home-manager instead of re-evaluating
- Safe modification: Test thoroughly on one host before rollout; monitor for package version mismatches between system and home

**Secrets Management Still Incomplete:**
- Issue: Secrets infrastructure (sops-nix) is integrated but some secrets files may not be fully populated
- Files: `hosts/*/secrets.nix`, `secrets/` directory (`.sops.yaml` configuration exists)
- Impact: Syncthing device IDs, SSH keys may have placeholder values; per-host deployment may fail if secrets aren't properly decrypted
- Current status: According to `TO-DOS.md` and `REFACTOR-SUMMARY.md`, WiFi password sops integration is planned (008-sops-wifi-passwords-plan.md) but not yet implemented
- Verification approach: On each host after rebuild, verify `sudo sops-nix-diff` shows correct decryption and that Syncthing starts cleanly

## Fragile Areas

**Multi-Host Configuration Synchronization:**
- Files: `hosts/common/configuration.nix`, `hosts/common/home.nix`
- Why fragile: Common config is shared across three different hardware platforms (Intel ThinkPad, AMD Desktop, AMD Surface). Changes to shared config may have unexpected effects on specific hosts due to hardware differences
- Safe modification: Use `lib.mkDefault` in common config to allow host-specific overrides; test changes on mischief (test machine) before deploying to intrepid (daily driver) and vigilant (Surface)
- Test coverage gap: No automated testing for config validity across all three hosts

**Evremap Keyboard Remapping Services:**
- Files: `hosts/mischief/configuration.nix` (lines 13-22), `hosts/intrepid/configuration.nix` (lines 30-39), `hosts/vigilant/configuration.nix` (lines 54-63)
- Why fragile: Three separate evremap systemd services with different TOML config files per host; if config file is missing or has syntax error, the service fails to restart and system loses custom keybindings
- Safe modification: Always verify config file exists before rebuilding; test keybindings immediately after system boot to catch failures early
- Test coverage gap: No pre-flight validation that TOML config files are syntactically valid before deployment

## Scaling Limits

**Large Shared Home Configuration:**
- Current size: `hosts/common/home.nix` is 239 lines with 50+ packages in single list
- Limit: Adding more packages or configuration blocks will make this file difficult to navigate and maintain
- Scaling path: Consider breaking home.nix into smaller modules (e.g., `home-common-languages.nix`, `home-common-tools.nix`, `home-common-wayland.nix`) and importing them in the main `home.nix`

**Package Accumulation Risk:**
- Issue: `hosts/common/home.nix` installs 50+ packages on all hosts unconditionally
- Impact: As more packages are added, slower home-manager evaluations; storage waste on minimal hosts like mischief (test machine)
- Scaling approach: Move host-specific packages (like Android SDK, eas-cli, watchman) to host-specific `home.nix` files rather than common config

**Nix Flake Evaluation Time:**
- Current: flake.nix is simple with 70 lines and three host configurations
- Concern: As custom packages increase (currently 1: waystt), flake evaluation may slow down
- Monitoring: Run `nix flake update && time nix flake check` periodically to track evaluation performance

## Missing Critical Features

**Backup System Not Configured:**
- Problem: No backup strategy for user data, configs, or system state across three hosts
- Blocks: Can't safely store important dotfiles outside git; no rollback mechanism for data loss
- Priority: High - Data loss risk on daily driver (intrepid) and work machine (vigilant)
- Solution from TO-DOS.md: Consider restic, borgbackup, or enhanced Syncthing for different backup needs (local snapshots vs offsite)

**Brave Browser Sync Not Configured:**
- Problem: Brave installed but sync not configured; bookmarks/settings won't persist across mischief, intrepid, vigilant
- Blocks: Browser customizations not synchronized across machines
- Priority: Medium - Workaround is manual sync via Brave's built-in sync chain feature
- Solution from TO-DOS.md: Create sync chain on one device, join from others using sync code

**WiFi Password Secrets Management:**
- Problem: Planned but not yet implemented
- Files: `plans/008-sops-wifi-passwords-plan.md` exists but no implementation
- Blocks: WiFi credentials not declaratively managed; switching between networks requires manual input
- Priority: Medium
- Solution path: Implement sops-encrypted WiFi secret files per host, similar to existing SSH keys and Syncthing secrets

## Dependencies at Risk

**Ghostty Terminal (Non-Mainline):**
- Risk: Ghostty is installed from separate flake input (`ghostty.url = "github:ghostty-org/ghostty"`) rather than nixpkgs
- Impact: Extra flake input to maintain; updates not synchronized with nixpkgs; diverges from stable channel
- Current: Works fine, but creates maintenance burden
- Migration plan: Monitor for ghostty inclusion in nixpkgs stable (nixos-25.05 or later); switch to nixpkgs version when available

**Fresh Text Editor (Non-Mainline):**
- Risk: Fresh editor installed from custom flake input (`fresh.url = "github:sinelaw/fresh"`)
- Impact: Similar to Ghostty; adds maintenance burden; relies on external repo staying active
- Migration plan: Consider switching to established editors in nixpkgs (Zed, VSCode, Neovim) if Fresh becomes unmaintained

**sops-nix Secrets Management:**
- Risk: Depends on external `sops-nix` module; if upstream breaks, secrets become inaccessible
- Current: sops-nix is widely used and actively maintained, but represents single point of failure for secrets decryption
- Mitigation: Keep backups of `.sops.yaml` and age keys outside repository; document recovery procedures

## Performance Bottlenecks

**Android SDK Installation:**
- Problem: Full Android SDK is compiled/installed as part of home-manager config (lines 9-16 in `hosts/common/home.nix`)
- Cause: `androidenv.composeAndroidPackages` with multiple versions (34, 35) and system images is large
- Impact: Slow home-manager evaluation on all hosts, even those not used for Android development
- Improvement path: Move `androidSdk` to a separate Nix file and only import it on mischief or intrepid (daily driver); wrap in `mkIf` conditional

**Large config/ Symlinks:**
- Problem: Entire `config/` directory (with large Neovim config, Niri, Waybar, OBS configs) is symlinked via home-manager on every host
- Impact: home-manager manages hundreds of small files; unnecessary churn when configs don't change
- Improvement path: Only symlink truly host-agnostic configs (nvim, zed, ghost); use `config-overrides/` more aggressively for per-host customization

## Test Coverage Gaps

**No Automated Configuration Validation:**
- What's not tested: Hardware configurations aren't tested against actual hardware after initial setup
- Files: `hosts/intrepid/hardware-configuration.nix`, `hosts/vigilant/hardware-configuration.nix`
- Risk: Silent failures when UUID-based mounts don't match; GPU drivers may not load on actual hardware
- Recommendation: Add post-rebuild verification steps in CLAUDE.md (e.g., check `lspci` for GPU, verify `lsblk` UUIDs)

**Secrets Decryption Not Validated:**
- What's not tested: sops secrets aren't decrypted during `nix flake check`
- Files: `hosts/*/secrets.nix`, `secrets/` directory
- Risk: Deployment will fail if age keys aren't available; no early warning during planning phase
- Recommendation: Add manual verification step: run `sops -d secrets/ssh/[hostname].yaml` before rebuilding each host

**Evremap Service Health Check:**
- What's not tested: Evremap config syntax isn't validated before systemd service starts
- Files: `config/evremap/*.toml`
- Risk: Keybindings break silently after rebuild if TOML is malformed
- Recommendation: Add pre-rebuild validation: `evremap verify config/evremap/*.toml` (if available) or manual test of keybinds immediately post-rebuild

---

*Concerns audit: 2026-03-20*
