# Phase 1: Flake Foundation - Research

**Researched:** 2026-03-20
**Domain:** NixOS flake inputs, nixosModules, overlay cleanup
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Input pinning**
- Source: `github:peteonrails/voxtype/v0.6.4` — pin to the tag, not default branch
- Set `voxtype.inputs.nixpkgs.follows = "nixpkgs"` to prevent double nixpkgs evaluation
- Updates are manual via `nix flake update voxtype`

**Module placement**
- Import `inputs.voxtype.nixosModules.default` in `hosts/common/configuration.nix`
- All three hosts get the module — consistent with the shared-by-default pattern
- Thread `inputs` through via existing `specialArgs`

**Package activation**
- Set `programs.voxtype.enable = true` in common config
- This makes the voxtype binary available as a system package immediately
- Package variant selection (CPU vs Vulkan) is Claude's discretion for Phase 1; Phase 2 overrides per-host via Home Manager

**Waystt cleanup**
- Remove the waystt overlay from `flake.nix` (both the overlay definition and `nixpkgs.overlays` usage in mkHost)
- Delete the `packages/waystt/` directory entirely
- Keep `waystt` in `environment.systemPackages` for now if needed for flake check to pass; Phase 2 handles the full systemPackages removal
- Keep `programs.ydotool.enable` — voxtype still uses it

### Claude's Discretion
- Default package variant for the nixosModule (CPU-only is the safe choice)
- Exact ordering of imports in common/configuration.nix
- Whether to pass voxtype input through specialArgs or extraSpecialArgs (follow existing repo pattern)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FLAKE-01 | Voxtype flake input added to flake.nix with nixpkgs.follows to avoid double evaluation | Confirmed pattern from existing inputs (sops-nix, home-manager, claude-code all use `.inputs.nixpkgs.follows = "nixpkgs"`). The tag `v0.6.4` exists on the GitHub repo. |
| FLAKE-02 | Voxtype nixosModule imported in common configuration.nix | Confirmed: `inputs.voxtype.nixosModules.default` is the correct output name from the flake. `inputs` is already available in common/configuration.nix via `specialArgs`. The module only adds `environment.systemPackages = [ cfg.package ]` when enabled — it does NOT auto-enable ydotool or add input group (both already configured in common config). |
| FLAKE-03 | Voxtype homeManagerModule imported in common home.nix | **SCOPE CONFLICT:** CONTEXT.md explicitly scopes Phase 1 to the nixosModule only; Home Manager config is Phase 2. FLAKE-03 as written contradicts the CONTEXT.md decision. Recommend the planner treat FLAKE-03 as out-of-scope for Phase 1 and flag for Phase 2. The homeManagerModule path is confirmed as `inputs.voxtype.homeManagerModules.default` for when Phase 2 needs it. |
</phase_requirements>

## Summary

Phase 1 makes three coordinated changes to the flake: add the voxtype input (pinned to v0.6.4 with nixpkgs.follows), import and enable the nixosModule in common configuration, and remove the legacy waystt overlay and package directory.

The voxtype flake at `github:peteonrails/voxtype` exports `nixosModules.default` (from `nix/nixos-module.nix`) and `homeManagerModules.default` (from `nix/home-manager-module.nix`). The nixosModule is minimal: when `programs.voxtype.enable = true`, it adds the selected package to `environment.systemPackages`. It does NOT auto-configure ydotool or input group membership — those are documented as manual steps. Both are already present in common/configuration.nix, so no additional setup is needed.

The waystt cleanup is straightforward: the overlay `final: prev: { waystt = ...; }` in flake.nix and the `nixpkgs.overlays = [ overlay ]` in mkHost are removed, and `packages/waystt/` is deleted. The `waystt` entry in `environment.systemPackages` in common/configuration.nix is left in place for Phase 1 to avoid breaking `nix flake check` — Phase 2 removes it when voxtype replaces it.

**Primary recommendation:** Add voxtype input with tag + follows, import nixosModules.default in common configuration.nix imports list, set `programs.voxtype.enable = true` with default CPU package, then strip the overlay infrastructure from flake.nix and delete `packages/waystt/`.

## Standard Stack

### Core
| Component | Version/Ref | Purpose | Why Standard |
|-----------|-------------|---------|--------------|
| voxtype flake input | `github:peteonrails/voxtype/v0.6.4` | Voice-to-text package source | Locked decision; v0.6.4 is the current release |
| nixosModules.default | v0.6.4 | System package installation via `programs.voxtype` interface | Only NixOS module the flake exports |
| nixpkgs.follows | follows `nixpkgs` | Prevents double nixpkgs evaluation | Same pattern used by all other inputs in this flake |

### Package Variants Available
| Variant | Description | When to Use |
|---------|-------------|-------------|
| `packages.x86_64-linux.default` | CPU-only Whisper | Safe default; works on all hosts |
| `packages.x86_64-linux.vulkan` | Vulkan GPU acceleration | AMD/NVIDIA GPU hosts (Phase 2 per-host override) |
| `packages.x86_64-linux.rocm` | AMD ROCm GPU | AMD-specific (Phase 2) |
| `packages.x86_64-linux.onnx` | ONNX Runtime CPU | Non-Whisper engines |

**For Phase 1:** Use the CPU default. The nixosModule's `cfg.package` defaults to the flake's default package (CPU Whisper).

## Architecture Patterns

### Existing flake.nix input pattern (HIGH confidence)
All existing inputs follow the same two-line form:
```nix
# In inputs block:
voxtype.url = "github:peteonrails/voxtype/v0.6.4";
voxtype.inputs.nixpkgs.follows = "nixpkgs";
```
This matches how sops-nix, home-manager, claude-code, and fresh are already declared.

### Existing mkHost pattern (HIGH confidence)
The nixosModule is added to the `modules` list inside `mkHost`. Other flake nixosModules are already imported this way:
```nix
modules = [
  ./hosts/${hostname}/configuration.nix
  inputs.sops-nix.nixosModules.sops       # existing pattern
  inputs.voxtype.nixosModules.default     # new, follows same pattern
  home-manager.nixosModules.home-manager
  { ... }
];
```
Since all hosts use `mkHost`, all three hosts get the module in a single addition.

### Enabling in common/configuration.nix (HIGH confidence)
The module is enabled in `hosts/common/configuration.nix` alongside other `programs.*` options:
```nix
programs.voxtype.enable = true;
```
No package option is required in Phase 1 — the default (CPU) is used. Phase 2 will override `programs.voxtype.package` per-host if Vulkan is desired.

### inputs threading (HIGH confidence)
`inputs` is already available in `hosts/common/configuration.nix` — the file signature is `{ config, lib, pkgs, inputs, ... }:` and `specialArgs = { inherit inputs; }` is set in `mkHost`. No change needed here.

### Overlay removal pattern (HIGH confidence)
The overlay is defined at the top of flake.nix and applied in mkHost:
```nix
# REMOVE this:
overlay = final: prev: {
  waystt = final.callPackage ./packages/waystt { };
};

# REMOVE this from the anonymous module in mkHost:
nixpkgs.overlays = [ overlay ];
```
After removal, `nixpkgs.overlays` in the mkHost anonymous module disappears entirely. The `claude-code.overlays.default` is applied in `hosts/common/configuration.nix` separately via `nixpkgs.overlays = [ inputs.claude-code.overlays.default ]` — that is NOT touched.

### waystt in systemPackages (HIGH confidence)
`waystt` appears in `environment.systemPackages` in `hosts/common/configuration.nix` (line 181). After the overlay is removed, `waystt` will be an undefined name and `nix flake check` will fail. **Leave the `waystt` entry in systemPackages for Phase 1.** Phase 2 removes it when voxtype takes over.

Wait — re-examining: after removing the overlay, `waystt` is not in pkgs at all, so it will fail at evaluation time. The CONTEXT.md decision says "Keep `waystt` in `environment.systemPackages` for now if needed for flake check to pass." This is the opposite of what's needed — once the overlay defining `waystt` is removed, the reference in systemPackages must also be removed or flake check will fail immediately. See the Pitfalls section.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime dependency bundling | Custom wrapper script adding wtype/ydotool/etc. to PATH | `packages.x86_64-linux.default` (already wrapped) | Voxtype flake wraps all deps: wtype, dotool, wl-clipboard, ydotool, xdotool, xclip, libnotify, pciutils |
| Per-host package variant selection | Conditional logic in common config | `programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan` per-host in Phase 2 | The nixosModule has a `package` option for exactly this |
| Manual nixpkgs deduplication | `nix why-depends` investigation | `.inputs.nixpkgs.follows = "nixpkgs"` | Single-line solution already used by all other inputs |

## Common Pitfalls

### Pitfall 1: Removing the overlay before removing the waystt systemPackages reference
**What goes wrong:** `nix flake check` fails with "undefined variable 'waystt'" because `pkgs.waystt` no longer exists once the overlay is removed.
**Why it happens:** The waystt overlay adds `waystt` to pkgs; removing it makes the name undefined at evaluation time.
**How to avoid:** Remove the `waystt` entry from `environment.systemPackages` in `hosts/common/configuration.nix` at the same time as removing the overlay from `flake.nix`. The CONTEXT.md wording "keep waystt in systemPackages if needed for flake check to pass" is misleading — keeping the reference while removing the overlay will cause a check failure. Remove both together.
**Warning signs:** `error: undefined variable 'waystt'` during `nix flake check` or `nixos-rebuild`.

### Pitfall 2: Double nixpkgs evaluation if follows is omitted
**What goes wrong:** Voxtype pins its own version of nixpkgs, causing a second nixpkgs download and evaluation during build.
**Why it happens:** Without `voxtype.inputs.nixpkgs.follows = "nixpkgs"`, Nix uses voxtype's locked nixpkgs independently.
**How to avoid:** Include the follows line immediately after the url line (consistent with all existing inputs).
**Warning signs:** Long first-build times, duplicate store paths visible in `nix why-depends`.

### Pitfall 3: Assuming the nixosModule auto-configures ydotool/input group
**What goes wrong:** Relying on the nixosModule to enable ydotool or add the user to the input group.
**Why it happens:** The CONTEXT.md specifics section says "The nixosModule handles ydotool enabling and input group membership automatically" — but inspection of the actual v0.6.4 module shows it only does `environment.systemPackages = [ cfg.package ]`. This is incorrect.
**How to avoid:** No action needed for Phase 1 because `programs.ydotool.enable = true` (line 85) and `input` in `users.users.dustin.extraGroups` (line 90) are already present in common/configuration.nix.
**Warning signs:** If ydotool is ever removed from the manual config expecting the module to handle it.

### Pitfall 4: Adding the nixosModule to mkHost modules list vs. importing in common/configuration.nix
**What goes wrong:** Two valid placement options create inconsistency with how the planner structures tasks.
**Why it happens:** The module can be added either to the `modules` list in `mkHost` (like sops-nix) OR to the `imports` list in `hosts/common/configuration.nix` (like nixos-hardware modules in per-host configs).
**How to avoid:** The CONTEXT.md decision says "Import `inputs.voxtype.nixosModules.default` in `hosts/common/configuration.nix`" — use the imports list in common/configuration.nix, NOT the mkHost modules list. This keeps all module imports visible within the configuration files rather than the flake plumbing.
**Warning signs:** Module added to mkHost instead of common/configuration.nix imports.

### Pitfall 5: Tag URL format in flake inputs
**What goes wrong:** Using branch ref syntax instead of tag ref syntax.
**Why it happens:** Nix flake URLs for GitHub support both `github:owner/repo/REF` where REF can be a branch or tag.
**How to avoid:** `github:peteonrails/voxtype/v0.6.4` is correct — Nix resolves this as a tag when it matches a tag, and it gets pinned in flake.lock. This is verified by the existing `ghostty` input which uses the default branch (no tag), confirming the syntax is already used in this repo.

## Code Examples

### Complete flake.nix input addition
```nix
# Source: existing repo pattern (sops-nix, claude-code, fresh)
# Add to inputs block in flake.nix:
voxtype.url = "github:peteonrails/voxtype/v0.6.4";
voxtype.inputs.nixpkgs.follows = "nixpkgs";
```

### Import and enable in common/configuration.nix
```nix
# Source: voxtype v0.6.4 nixos-module.nix + existing repo pattern
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.voxtype.nixosModules.default
    # ... existing imports would go here if any
  ];

  # ... existing config ...

  programs.voxtype.enable = true;
  # programs.voxtype.package defaults to the CPU variant — no override needed for Phase 1
}
```

### Overlay removal from flake.nix
```nix
# BEFORE (remove these):
overlay = final: prev: {
  waystt = final.callPackage ./packages/waystt { };
};

# In mkHost, remove:
nixpkgs.overlays = [ overlay ];
```

### Waystt removal from environment.systemPackages in common/configuration.nix
```nix
# Remove this line from environment.systemPackages:
waystt                   # Wayland speech-to-text
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-rolled `packages/waystt/` overlay | Official voxtype flake with nixosModule | voxtype v0.6.x | Drop custom build logic; gain upstream maintenance |
| No programs.voxtype abstraction | `programs.voxtype.enable = true` with package option | v0.6.3+ NixOS packaging improvements | Clean declarative interface |

**Deprecated/outdated:**
- `packages/waystt/default.nix`: Custom Rust build with Vulkan patching — replace entirely with voxtype flake
- The local overlay pattern for waystt: no longer needed

## Open Questions

1. **FLAKE-03 scope conflict**
   - What we know: FLAKE-03 requires homeManagerModule in common home.nix; CONTEXT.md explicitly defers all Home Manager config to Phase 2
   - What's unclear: Whether FLAKE-03 was written before the CONTEXT.md discussion narrowed scope, or whether it is genuinely intended for Phase 1
   - Recommendation: Treat FLAKE-03 as out-of-scope for Phase 1. The homeManagerModule import (`inputs.voxtype.homeManagerModules.default`) is confirmed available for Phase 2. The planner should note this discrepancy and either skip FLAKE-03 or flag it for the user.

2. **waystt removal timing**
   - What we know: CONTEXT.md says "Keep `waystt` in environment.systemPackages for now if needed for flake check to pass" — but this contradicts reality: keeping the reference after overlay removal causes evaluation failure
   - What's unclear: The intent may have been "keep the waystt binary available some other way" not "keep the broken reference"
   - Recommendation: Remove both the overlay definition AND the `waystt` systemPackages entry in the same change. The voxtype package provides the replacement binary; leaving waystt as a system package is not necessary.

## Sources

### Primary (HIGH confidence)
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/flake.nix` — package variants, nixosModules.default and homeManagerModules.default output names confirmed
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/nix/nixos-module.nix` — exact module implementation: only `environment.systemPackages = [ cfg.package ]`
- `https://raw.githubusercontent.com/peteonrails/voxtype/v0.6.4/nix/home-manager-module.nix` — homeManagerModule structure confirmed for Phase 2 reference
- `/home/dustin/nixos-dotfiles/flake.nix` — existing input patterns, mkHost structure, overlay location confirmed
- `/home/dustin/nixos-dotfiles/hosts/common/configuration.nix` — ydotool already enabled (line 85), input group already in extraGroups (line 90), waystt in systemPackages (line 181), claude-code overlay location (line 193-195)

### Secondary (MEDIUM confidence)
- `https://github.com/peteonrails/voxtype/releases` — v0.6.4 confirmed as current release (March 20, 2025); tag exists

### Tertiary (LOW confidence)
- WebSearch result: voxtype.io/news — NixOS packaging improvements in v0.6.3, @digunix and @DuskyElf as packaging co-owners

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fetched actual flake.nix and module source at v0.6.4 tag
- Architecture: HIGH — read actual repo files, existing patterns confirmed from source
- Pitfalls: HIGH for overlay removal pitfall (directly verifiable from source); MEDIUM for the ydotool auto-config discrepancy (read actual module source, contradicts CONTEXT.md claim)

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable flake, pinned tag, 30 days)
