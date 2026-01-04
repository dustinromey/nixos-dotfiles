<objective>
Add Brave web browser to the NixOS configuration.

Brave is a privacy-focused Chromium-based browser. Adding it alongside Firefox provides a second browser option.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Current browser setup:
- Firefox is enabled via `programs.firefox.enable = true` in configuration.nix

The existing pattern uses both:
- `programs.X.enable` for programs with NixOS modules
- `environment.systemPackages` for simple package installs

@configuration.nix - Where Firefox is configured
@home.nix - Alternative location for user packages
</context>

<requirements>
1. Install Brave browser
2. Follow existing patterns in the codebase
3. Keep it simple - no extra configuration needed
</requirements>

<implementation>
Brave can be added via environment.systemPackages in configuration.nix:
```nix
environment.systemPackages = with pkgs; [
  # ... existing packages
  brave
];
```

Alternatively, add to home.nix home.packages if you prefer user-level installation.
Choose whichever is more consistent with existing patterns (configuration.nix has Firefox, so system-level makes sense).
</implementation>

<output>
Modify `./configuration.nix` - Add brave to environment.systemPackages
</output>

<verification>
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. Run `brave` from terminal or find in app launcher
</verification>

<success_criteria>
- Brave browser launches successfully
- Available in Rofi app launcher
</success_criteria>
