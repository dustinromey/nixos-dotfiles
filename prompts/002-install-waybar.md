<objective>
Install Waybar as the status bar for Niri with a Tokyo Night color scheme.

Waybar is a highly customizable Wayland bar that works well with Niri.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Color scheme (Tokyo Night inspired):
- Background: #1a1b26
- Foreground: #c0caf5
- Accent blue: #7aa2f7
- Accent purple: #ad8ee6
- Accent cyan: #7fc8ff
- Inactive: #505050

@home.nix - Add waybar package here
@config/niri/config.kdl - Add spawn-at-startup for waybar
</context>

<requirements>
1. Install waybar package via home-manager
2. Create waybar config directory with config and style.css
3. Add waybar to configs symlink map in home.nix
4. Enable spawn-at-startup in config/niri/config.kdl
</requirements>

<implementation>
Step 1: Add waybar to home.nix home.packages

Step 2: Add waybar to configs symlink map

Step 3: Create config/waybar/config.jsonc with:
- Left: workspaces
- Center: clock
- Right: pulseaudio, network, battery, tray

Step 4: Create config/waybar/style.css with Tokyo Night colors

Step 5: Uncomment spawn-at-startup "waybar" in config/niri/config.kdl
</implementation>

<output>
Modify:
- ./home.nix - Add waybar package and config symlink
- ./config/niri/config.kdl - Enable waybar spawn

Create:
- ./config/waybar/config.jsonc
- ./config/waybar/style.css
</output>

<verification>
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. Log into Niri session
3. Waybar should appear at top of screen
</verification>

<success_criteria>
- Waybar launches automatically with Niri
- Status bar displays workspaces, clock, system info
- Tokyo Night colors applied
</success_criteria>
