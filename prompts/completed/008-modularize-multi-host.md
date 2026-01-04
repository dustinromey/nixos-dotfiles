<objective>
Modularize the NixOS flake configuration to support multiple hosts while sharing common configuration. This enables using the same repository across three machines with different hardware, while allowing per-host customization of both NixOS config and application configs in ./config/.

Hosts to support:
- **intrepid**: Desktop, AMD CPU/GPU, 32GB RAM (daily driver)
- **vigilant**: Microsoft Surface Laptop 4, AMD CPU/GPU, 16GB RAM
- **mischief**: Lenovo ThinkPad X270, Intel i5-6300U, Intel HD 520 GPU, test machine (current)
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Current structure has a single configuration.nix and home.nix. We need to refactor to:
1. Share common config across all hosts
2. Allow per-host hardware configuration
3. Allow per-host overrides for ./config/ application configs (niri, waybar, etc.)
4. Keep mischief working exactly as it does now (it's the reference implementation)

@flake.nix - Entry point, needs multi-host outputs
@configuration.nix - System config to modularize
@home.nix - User config to modularize
@hardware-configuration.nix - Currently mischief-specific
</context>

<requirements>
1. **Restructure directory layout** to support multiple hosts:
   ```
   nixos-dotfiles/
   ├── flake.nix                    # Multi-host outputs
   ├── hosts/
   │   ├── common/
   │   │   ├── configuration.nix    # Shared system config
   │   │   └── home.nix             # Shared home-manager config
   │   ├── mischief/
   │   │   ├── configuration.nix    # Host-specific overrides
   │   │   ├── home.nix             # Host-specific home overrides
   │   │   └── hardware-configuration.nix
   │   ├── intrepid/
   │   │   ├── configuration.nix    # AMD GPU drivers, etc.
   │   │   ├── home.nix
   │   │   └── hardware-configuration.nix  # Placeholder
   │   └── vigilant/
   │       ├── configuration.nix    # Surface-specific (touchscreen?)
   │       ├── home.nix
   │       └── hardware-configuration.nix  # Placeholder
   ├── config/                       # Shared application configs
   │   ├── niri/
   │   ├── waybar/
   │   └── ...
   └── config-overrides/             # Per-host config overrides
       ├── intrepid/
       │   └── niri/config.kdl       # Example: different monitor setup
       └── vigilant/
           └── waybar/style.css      # Example: different scaling
   ```

2. **Update flake.nix** to generate nixosConfigurations for all three hosts:
   - `nixosConfigurations.mischief`
   - `nixosConfigurations.intrepid`
   - `nixosConfigurations.vigilant`

   Each should import common config + host-specific overrides.

3. **Refactor configuration.nix**:
   - Move current content to `hosts/common/configuration.nix`
   - Create `hosts/mischief/configuration.nix` that imports common + adds hostname
   - Create placeholder configs for intrepid and vigilant with appropriate:
     - AMD GPU drivers for intrepid/vigilant
     - Intel drivers for mischief (already configured)

4. **Refactor home.nix**:
   - Move current content to `hosts/common/home.nix`
   - Create host-specific home.nix files that can override configs
   - Implement config override mechanism: if a file exists in `config-overrides/{hostname}/`, use it instead of the default in `config/`

5. **Keep mischief working identically** - this is the test machine, so the refactor must not change its behavior.

6. **Document the pattern** in CLAUDE.md for future reference.
</requirements>

<implementation>
Use NixOS module system best practices:
- Common modules should be parameterized where needed
- Use `mkDefault` for values that hosts might override
- Use `lib.mkForce` sparingly, prefer `mkDefault` in common config
- The config symlink pattern should check for host-specific override first

For the config override mechanism in home.nix, implement logic like:
```nix
let
  hostname = config.networking.hostName;  # or pass as argument
  configPath = name:
    let override = ./config-overrides/${hostname}/${name};
    in if builtins.pathExists override
       then override
       else ./config/${name};
in {
  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink (configPath subpath);
      recursive = true;
    })
    configs;
}
```

For AMD GPU hosts (intrepid, vigilant), include:
```nix
hardware.graphics.enable = true;
hardware.graphics.extraPackages = with pkgs; [ amdvlk ];
```
</implementation>

<output>
Create/modify files:
- `./flake.nix` - Update with multi-host outputs
- `./hosts/common/configuration.nix` - Shared system config
- `./hosts/common/home.nix` - Shared home-manager config
- `./hosts/mischief/configuration.nix` - Mischief-specific
- `./hosts/mischief/home.nix` - Mischief-specific
- `./hosts/mischief/hardware-configuration.nix` - Move existing
- `./hosts/intrepid/configuration.nix` - AMD desktop config
- `./hosts/intrepid/home.nix` - Placeholder
- `./hosts/intrepid/hardware-configuration.nix` - Placeholder with TODO
- `./hosts/vigilant/configuration.nix` - Surface laptop config
- `./hosts/vigilant/home.nix` - Placeholder
- `./hosts/vigilant/hardware-configuration.nix` - Placeholder with TODO
- `./config-overrides/.gitkeep` - Create directory structure
- `./CLAUDE.md` - Update with multi-host documentation
</output>

<verification>
1. Run `nix flake check` to verify flake syntax
2. Run `sudo nixos-rebuild switch --flake .#mischief` on current machine to verify mischief still works
3. Verify the directory structure matches the specification
4. Check that common config is properly imported by all hosts
</verification>

<success_criteria>
- All three hosts defined in flake.nix outputs
- Mischief continues to work exactly as before
- Common configuration is shared, not duplicated
- Host-specific overrides are cleanly separated
- Config override mechanism for ./config/ files is implemented
- AMD GPU support scaffolded for intrepid/vigilant
- CLAUDE.md updated with multi-host documentation
- Directory structure is clean and intuitive
</success_criteria>
