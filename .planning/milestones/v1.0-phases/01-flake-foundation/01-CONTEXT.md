# Phase 1: Flake Foundation - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add voxtype as a flake input, import its NixOS module in common configuration, enable it so voxtype is available as a system package, and remove the legacy waystt overlay and package directory. No daemon activation, no Home Manager config, no keybindings — those are Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Input pinning
- Source: `github:peteonrails/voxtype/v0.6.4` — pin to the tag, not default branch
- Set `voxtype.inputs.nixpkgs.follows = "nixpkgs"` to prevent double nixpkgs evaluation
- Updates are manual via `nix flake update voxtype`

### Module placement
- Import `inputs.voxtype.nixosModules.default` in `hosts/common/configuration.nix`
- All three hosts get the module — consistent with the shared-by-default pattern
- Thread `inputs` through via existing `specialArgs`

### Package activation
- Set `programs.voxtype.enable = true` in common config
- This makes the voxtype binary available as a system package immediately
- Package variant selection (CPU vs Vulkan) is Claude's discretion for Phase 1; Phase 2 overrides per-host via Home Manager

### Waystt cleanup
- Remove the waystt overlay from `flake.nix` (both the overlay definition and `nixpkgs.overlays` usage in mkHost)
- Delete the `packages/waystt/` directory entirely
- Keep `waystt` in `environment.systemPackages` for now if needed for flake check to pass; Phase 2 handles the full systemPackages removal
- Keep `programs.ydotool.enable` — voxtype still uses it

### Claude's Discretion
- Default package variant for the nixosModule (CPU-only is the safe choice)
- Exact ordering of imports in common/configuration.nix
- Whether to pass voxtype input through specialArgs or extraSpecialArgs (follow existing repo pattern)

</decisions>

<specifics>
## Specific Ideas

- Research identified the flake at `github:peteonrails/voxtype` with v0.6.4 as current release
- The nixosModule handles ydotool enabling and input group membership automatically
- The repo already passes `inputs` via `specialArgs` — follow that existing pattern

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-flake-foundation*
*Context gathered: 2026-03-20*
