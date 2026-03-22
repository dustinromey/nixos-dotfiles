# Phase 04: Add claude-for-linux to NixOS Setup - Research

**Researched:** 2026-03-22
**Domain:** NixOS flake packaging, Electron apps on Linux, Wayland compatibility
**Confidence:** HIGH

<user_constraints>
## User Constraints (from phase context)

### Locked Decisions
- Install BOTH Claude Code CLI and Claude desktop Linux app
- Use the simplest NixOS packaging approach
- Standalone install only — no MCP server configuration
- All hosts share the same packages via common home.nix

### Claude's Discretion
- Whether to use nixpkgs existing packages, custom derivations, or flake inputs
- How to handle updates/versioning
- Desktop entry details

### Deferred Ideas (OUT OF SCOPE)
- MCP server configuration
- Per-host differentiation for Claude packages
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLAUDE-01 | Claude Code CLI installed via Nix and available in PATH on all hosts | Already partially done: `ryoppippi/claude-code-overlay` is an input, overlay is applied in `configuration.nix`, and `claude-code` is in `home.packages`. Verify correctness and version currency. |
| CLAUDE-02 | Claude desktop app installed with desktop entry and icon | NOT yet done. Requires adding `k3d3/claude-desktop-linux-flake` as a flake input and referencing the package in `home.packages`. The package auto-includes a desktop entry. |
| CLAUDE-03 | Both claude packages added through common home.nix (shared across hosts) | `claude-code` is already in `hosts/common/home.nix`. Desktop app package reference must go to the same file. |
| CLAUDE-04 | `nix flake check` passes with claude packages present | Unfree is already permitted (`allowUnfree = true` in `configuration.nix`). Desktop flake requires `flake-utils` input which is not currently in the flake — add it as an input. |
</phase_requirements>

## Summary

The repository is ahead of where this phase starts: Claude Code CLI is already integrated via the `ryoppippi/claude-code-overlay` flake. The overlay is applied in `hosts/common/configuration.nix`, `allowUnfree = true` is set, and `claude-code` appears in `home.packages` in `hosts/common/home.nix`. The primary work for this phase is adding the Claude desktop app.

The simplest approach for the desktop app is `k3d3/claude-desktop-linux-flake`. It is a focused Nix flake that packages Claude Desktop for Linux by extracting the Windows installer and replacing native bindings with a Linux-compatible NAPI-RS stub (`patchy-cnb`). The package automatically includes a `.desktop` file (name="Claude", exec="claude-desktop %u", categories=Office/Utility, MIME=x-scheme-handler/claude), so no manual `xdg.desktopEntries` definition is needed. Since standalone only (no MCP), the standard `claude-desktop` package is correct — `claude-desktop-with-fhs` is only needed for MCP servers.

The one complication: `k3d3/claude-desktop-linux-flake` depends on `flake-utils`, which is not currently in the repo's `flake.nix`. It must be added as a flake input with `inputs.flake-utils.follows` set appropriately. This is a small addition but must be done or `nix flake check` will fail.

**Primary recommendation:** Add `k3d3/claude-desktop-linux-flake` as a flake input (with `flake-utils` dependency), reference `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` in `home.packages`, and verify the existing Claude Code CLI setup is complete.

## Current State Assessment

What is ALREADY done in the repo (do not re-do):

| Item | Location | Status |
|------|----------|--------|
| `claude-code` flake input | `flake.nix` line 9-11 | Done — `github:ryoppippi/claude-code-overlay` |
| Overlay applied | `hosts/common/configuration.nix` lines 220-222 | Done — `inputs.claude-code.overlays.default` |
| `allowUnfree = true` | `hosts/common/configuration.nix` lines 225-228 | Done |
| `claude-code` in home packages | `hosts/common/home.nix` line 141 | Done |

What is NOT done (the actual work):

| Item | Action Required |
|------|----------------|
| Claude desktop flake input | Add `claude-desktop.url = "github:k3d3/claude-desktop-linux-flake"` to `flake.nix` |
| `flake-utils` dependency | Add `flake-utils.url = "github:numtide/flake-utils"` and wire as follows in desktop input |
| Claude desktop in home packages | Add `inputs.claude-desktop.packages.${pkgs.system}.claude-desktop` to `home.packages` |

## Standard Stack

### Core Packages

| Package | Source | Version | Purpose | Why |
|---------|--------|---------|---------|-----|
| `claude-code` | `ryoppippi/claude-code-overlay` | Latest (auto-updated) | Claude Code CLI | Already in repo; pre-built binaries from Anthropic, updated frequently |
| `claude-desktop` | `k3d3/claude-desktop-linux-flake` | 0.14.10 (latest tracked) | Claude desktop Electron app | Simplest focused Nix flake for this purpose; no Home Manager module needed since standalone-only |

### Why `k3d3/claude-desktop-linux-flake` Over Alternatives

| Alternative | Why Not |
|-------------|---------|
| `heytcass/claude-for-linux` | Adds Home Manager module complexity that isn't needed for standalone install; extracts from macOS DMG (more fragile build) |
| `aaddrick/claude-desktop-debian` | Primarily for Debian-based distros; Nix flake is secondary |
| Build from scratch / custom derivation | Unnecessary complexity when community flake exists |
| nixpkgs `claude-desktop` | Does NOT exist — the nixpkgs issue (#366213) was closed as "not planned" in September 2025 |

### Why Keeping `ryoppippi/claude-code-overlay` for CLI

| Alternative | Why Not |
|-------------|---------|
| nixpkgs `claude-code` (version 1.0.85 in 25.05) | Version lags behind; ryoppippi overlay auto-updates every 3 hours, matching Anthropic releases |
| `sadjow/claude-code-nix` | Hourly updates but adds another input when ryoppippi is already configured |

## Architecture Patterns

### Recommended File Changes

```
flake.nix                    # Add claude-desktop input + flake-utils
hosts/common/home.nix        # Add claude-desktop package reference
```

No changes needed to:
- `hosts/common/configuration.nix` — overlay and allowUnfree already set
- Host-specific files — shared via common as required

### Pattern: Flake Input for External Package (No Overlay)

The desktop app does not use an overlay pattern. Reference the package directly via `inputs` in `home.nix`. This is the same pattern used for `fresh` in the repo:

```nix
# In flake.nix inputs:
claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
# flake-utils is required by k3d3's flake:
flake-utils.url = "github:numtide/flake-utils";
claude-desktop.inputs.flake-utils.follows = "flake-utils";
```

```nix
# In hosts/common/home.nix, inside home.packages:
inputs.claude-desktop.packages.${pkgs.system}.claude-desktop
```

### Pattern: Existing `fresh` Package as Reference

The repo already uses this exact pattern for the Fresh text editor:
```nix
# flake.nix:
fresh.url = "github:sinelaw/fresh";
fresh.inputs.nixpkgs.follows = "nixpkgs";

# home.nix:
inputs.fresh.packages.${pkgs.system}.default
```

The desktop app follows identical structure.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Linux-compatible native bindings for Claude Desktop | Custom NAPI-RS stub | `patchy-cnb` (bundled in k3d3 flake) | Already solved; reimplementing is complex |
| Desktop entry for Claude | Manual `xdg.desktopEntries` | Package auto-includes `.desktop` file | k3d3's package handles this automatically |
| Electron Wayland flags | Wrapping with custom script | XWayland-satellite (already in repo) | Repo already has XWayland running; Claude Desktop defaults to XWayland which is correct |

**Key insight:** For standalone-only installs, the k3d3 package is complete as-is. No wrappers, no custom desktop entries, no FHS environment needed.

## Common Pitfalls

### Pitfall 1: Missing `flake-utils` Input
**What goes wrong:** `nix flake check` fails with "input 'flake-utils' is not an input" or similar lock file error.
**Why it happens:** `k3d3/claude-desktop-linux-flake` lists `flake-utils` as a dependency. If it's not in the parent flake, Nix fetches it independently and the `follows` directive cannot be set.
**How to avoid:** Add `flake-utils.url = "github:numtide/flake-utils"` to `flake.nix` inputs and set `claude-desktop.inputs.flake-utils.follows = "flake-utils"`.
**Warning signs:** Build errors mentioning `flake-utils` not found or hash mismatches.

### Pitfall 2: Using `claude-desktop-with-fhs` Instead of `claude-desktop`
**What goes wrong:** Unnecessary FHS environment overhead; pulls in Docker, glibc, OpenSSL, Node.js, uv as runtime dependencies.
**Why it happens:** Documentation mentions FHS variant prominently for MCP use cases.
**How to avoid:** Since MCP is out of scope, always use `claude-desktop` (the standard package).

### Pitfall 3: Defining a Manual `xdg.desktopEntries` for Claude Desktop
**What goes wrong:** Duplicate or conflicting desktop entries; wasted effort.
**Why it happens:** The pattern of manually defining desktop entries (as done in home.nix for Brave, Ghostty) makes it seem necessary.
**How to avoid:** The k3d3 package auto-generates and installs a `.desktop` file. Adding one via `xdg.desktopEntries` creates a duplicate. Verify Rofi picks it up from the package's desktop entry before adding any manual override.

### Pitfall 4: Assuming Claude Desktop Needs Wayland Flags
**What goes wrong:** Unnecessary complexity adding environment variables or wrappers for Wayland.
**Why it happens:** Niri is a Wayland compositor; other Electron apps in the repo use XWayland.
**How to avoid:** Claude Desktop defaults to XWayland mode (recommended). XWayland-satellite is already running via systemd in the repo. Native Wayland via `CLAUDE_USE_WAYLAND=1` breaks global shortcuts and window positioning — stick with XWayland default.

### Pitfall 5: Version Lock Confusion for Claude Code CLI
**What goes wrong:** `claude --version` shows stale version; Anthropic releases break due to hash mismatch.
**Why it happens:** ryoppippi's overlay auto-updates but the `flake.lock` pins the version. Running `nix flake update claude-code` updates to latest.
**How to avoid:** Use `nix flake update claude-code` when updating Claude Code specifically. The overlay handles version tracking — do not pin to a specific version in the package derivation.

## Code Examples

### flake.nix — Add Desktop Input

```nix
# Source: existing repo pattern (fresh, voxtype)
inputs = {
  # ... existing inputs ...

  # Claude Desktop Linux app
  claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
  claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
  flake-utils.url = "github:numtide/flake-utils";
  claude-desktop.inputs.flake-utils.follows = "flake-utils";
};
```

### hosts/common/home.nix — Add Desktop Package

```nix
# Source: k3d3/claude-desktop-linux-flake README
home.packages = with pkgs; [
  # ... existing packages ...
  inputs.claude-desktop.packages.${pkgs.system}.claude-desktop
];
```

### Verification Commands

```bash
# After rebuild, verify CLI
claude --version

# Verify desktop entry exists
ls ~/.nix-profile/share/applications/ | grep claude
# or
ls /run/current-system/sw/share/applications/ | grep claude

# Verify flake check passes
nix flake check

# Rebuild all hosts
sudo nixos-rebuild switch --flake .#vigilant
sudo nixos-rebuild switch --flake .#intrepid
sudo nixos-rebuild switch --flake .#mischief
```

## State of the Art

| Topic | Current Approach | Notes |
|-------|-----------------|-------|
| Claude Code on NixOS | `ryoppippi/claude-code-overlay` OR nixpkgs `claude-code` | Overlay preferred for freshness; nixpkgs lags |
| Claude Desktop on Linux | Unofficial community flakes only | No official Linux release; nixpkgs request closed "not planned" (Sep 2025) |
| Electron Wayland on NixOS | `NIXOS_OZONE_WL=1` env var for native Wayland | Claude Desktop recommends XWayland (default) for full functionality |
| Electron 38+ Wayland | Auto-detected, no flags needed | Claude Desktop currently uses Electron < 38; check flake for exact version |

**Not applicable here:**
- `claude-desktop-with-fhs` — only needed for MCP servers (out of scope)
- `heytcass/claude-for-linux` Home Manager module — only needed if declarative module options wanted

## Open Questions

1. **Does `k3d3/claude-desktop-linux-flake` require `flake-utils` as a hard dependency?**
   - What we know: The README instructs adding `inputs.flake-utils.follows = "flake-utils"`
   - What's unclear: Whether it will build without `flake-utils` declared in parent, or auto-fetch it
   - Recommendation: Add `flake-utils` to parent flake to be safe and avoid unpinned dependencies

2. **Does the k3d3 package desktop entry get picked up by Rofi automatically?**
   - What we know: k3d3 installs a `.desktop` file; Rofi reads from `$XDG_DATA_DIRS`
   - What's unclear: Whether NixOS's XDG data path includes per-package desktop files for home.packages installs
   - Recommendation: After rebuild, test with `rofi -show drun` to confirm "Claude" appears; if not, add a minimal `xdg.desktopEntries` override as fallback

3. **Is the existing `claude-code` in `home.packages` pulling from the overlay correctly?**
   - What we know: `claude-code` overlay is applied in `configuration.nix`, package referenced by name in `home.packages` as `claude-code`
   - What's unclear: Whether `useGlobalPkgs = true` in flake.nix properly propagates the overlay to home-manager's pkgs
   - Recommendation: Run `claude --version` after rebuild to confirm; if it fails, switch to direct `inputs.claude-code.packages.${pkgs.system}.default` reference

## Sources

### Primary (HIGH confidence)
- `github:ryoppippi/claude-code-overlay` — Examined README and flake structure; overlay + packages approach confirmed
- `github:k3d3/claude-desktop-linux-flake` — Examined README and `pkgs/claude-desktop.nix`; desktop entry, package names, and flake-utils dependency confirmed
- `hosts/common/configuration.nix` (this repo) — Verified existing overlay, allowUnfree, and flake inputs
- `hosts/common/home.nix` (this repo) — Verified `claude-code` already in packages, existing `inputs.fresh.packages.${pkgs.system}.default` pattern
- `flake.nix` (this repo) — Verified `claude-code.url` input already present, `flake-utils` NOT present

### Secondary (MEDIUM confidence)
- mynixos.com — Confirmed `claude-code` in nixpkgs at version 1.0.85 (nixos-25.05 channel)
- NixOS Discourse packaging thread — Confirmed nixpkgs integration history, community approaches
- `github:NixOS/nixpkgs/issues/366213` — Confirmed claude-desktop nixpkgs request closed "not planned" September 2025

### Tertiary (LOW confidence)
- WebSearch results on Electron Wayland flags — Multiple sources agree Claude Desktop recommends XWayland mode; global shortcuts/positioning fail with native Wayland

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Direct examination of existing repo state and referenced flake READMEs
- Architecture: HIGH — Existing `fresh` pattern in repo is identical to what's needed; well-understood
- Pitfalls: MEDIUM — Flake-utils dependency confirmed from docs; Wayland behavior from multiple community sources

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (k3d3 flake actively maintained; check for version bumps)
