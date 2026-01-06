<objective>
Install Noctalia Shell (a Quickshell-based bar/panel for Niri) following the approach from https://tonybtw.com/tutorial/niri.

Noctalia Shell provides a status bar, app launcher integration, and system tray for Niri.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Noctalia Shell requires:
- The quickshell and noctalia flake inputs
- Adding the package to home.packages or environment.systemPackages
- A configuration directory at ~/.config/quickshell/noctalia/

Reference article: https://tonybtw.com/tutorial/niri
The article shows adding flake inputs for quickshell and noctalia.

@flake.nix - Add noctalia input here
@configuration.nix - System packages
@home.nix - Home-manager config (preferred location for user packages)
</context>

<requirements>
1. Add the noctalia flake input to flake.nix
2. Install noctalia-shell package via home-manager (consistent with existing pattern)
3. Create initial noctalia config directory and settings
4. Configure noctalia to spawn at Niri startup
</requirements>

<implementation>
Step 1: Add to flake.nix inputs:
```nix
noctalia.url = "github:Xepheryy/noctalia";
noctalia.inputs.nixpkgs.follows = "nixpkgs";
```

Step 2: Pass inputs to home-manager (already done via extraSpecialArgs)

Step 3: Add to home.nix home.packages:
```nix
inputs.noctalia.packages.${pkgs.system}.default
```

Step 4: Create config/quickshell/noctalia/ directory with:
- settings.json (bar configuration)
- colors.json (Tokyo Night theme to match existing setup)

Step 5: Add quickshell/noctalia to the configs symlink map in home.nix

Step 6: Add spawn-at-startup to config/niri/config.kdl:
```kdl
spawn-at-startup "noctalia-shell"
```
</implementation>

<output>
Modify:
- `./flake.nix` - Add noctalia input
- `./home.nix` - Add noctalia package and config symlink
- `./config/niri/config.kdl` - Add spawn-at-startup for noctalia-shell

Create:
- `./config/quickshell/noctalia/settings.json` - Basic bar settings
- `./config/quickshell/noctalia/colors.json` - Tokyo Night theme colors
</output>

<verification>
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. Log into Niri sessionw
3. Noctalia bar should appear automatically
</verification>

<success_criteria>
- Noctalia shell launches automatically with Niri
- Status bar displays at top/bottom of screen
- Tokyo Night theme colors applied
</success_criteria>
