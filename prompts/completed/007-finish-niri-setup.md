<objective>
Complete the Niri Wayland session setup by installing and configuring remaining tools:
- swaylock (lock screen)
- swayosd (on-screen display for volume/brightness)
- swww (wallpaper daemon with random selection)
- mako (notification daemon)
- polkit-kde (authentication agent)
- Clean up broken/unused commands in niri config
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

The niri config has several broken keybinds and startup commands from a previous non-NixOS setup (CachyOS/Omarchy). These need to be fixed or removed.

Key NixOS considerations:
- Paths like `/usr/lib/...` don't exist - use NixOS service modules instead
- `spawn-sh` has PATH issues - use `spawn "bash" "-c" "..."` or `spawn` with full paths
- Shebangs must use `#!/usr/bin/env bash` not `#!/bin/bash`

@home.nix - Add packages here
@configuration.nix - System-level config if needed
@config/niri/config.kdl - Fix keybinds and startup commands
</context>

<requirements>
1. **Install packages** in home.nix:
   - swaylock (or swaylock-effects for fancier lock screen)
   - swayosd
   - swww
   - mako
   - playerctl (for media key support)
   - brightnessctl (for brightness control)

2. **Configure polkit** - NixOS has a proper way to enable polkit agents. Check if `security.polkit.enable` or similar is needed in configuration.nix.

3. **Fix niri keybinds** that currently use broken commands:
   - `MOD+ALT+L` (lock screen): Use swaylock properly
   - `Mod+Shift+W` (wallpaper): Use swww with path `~/Pictures/walls/`
   - `Mod+R`, `Mod+Shift+R` (speech-to-text): Comment out for now (waystt not available in nixpkgs)
   - Audio keys (XF86Audio*): Use swayosd-client
   - Brightness keys (XF86MonBrightness*): Use swayosd-client
   - `MOD+PRINT` (color picker): Remove hyprpicker (not installed)

4. **Fix niri startup commands** - Remove or fix these broken lines:
   - Remove: `/usr/lib/polkit-kde-authentication-agent-1` (wrong path)
   - Remove: `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1` (wrong path)
   - Remove: `elephant` and `walker` lines (not installed, using rofi)
   - Remove: `swaybg` line (using swww instead)
   - Fix: `mako` - change spawn-sh to spawn
   - Fix: `swayosd-server` - change spawn-sh to spawn
   - Add: `swww-daemon` startup

5. **Create mako config** at `config/mako/config` with Tokyo Night theme colors matching waybar

6. **Update home.nix** to symlink mako config directory
</requirements>

<implementation>
Step 1: Add packages to home.nix home.packages:
```nix
swaylock
swayosd
swww
mako
playerctl
brightnessctl
```

Step 2: Add mako to the configs symlink map in home.nix

Step 3: Create config/mako/config with Tokyo Night colors:
- background: #1a1b26
- text: #c0caf5
- border: #7aa2f7

Step 4: Update niri config keybinds to use working commands

Step 5: Clean up niri startup section - remove broken commands, add working ones

Step 6: For polkit on NixOS, the KDE portal setup should handle it. If not, we may need:
```nix
security.polkit.enable = true;
```
And a startup command for the agent.
</implementation>

<output>
Modify:
- `./home.nix` - Add packages and mako config symlink
- `./config/niri/config.kdl` - Fix keybinds and startup commands
Create:
- `./config/mako/config` - Notification daemon configuration
</output>

<verification>
1. Run `niri validate` on the config to ensure syntax is correct
2. List all spawn-sh commands and verify they're either removed or have valid paths
3. Verify all added packages exist in nixpkgs: `nix search nixpkgs#swaylock` etc.
</verification>

<success_criteria>
- All packages added to home.nix
- Mako config created with Tokyo Night theme
- Niri config has no broken spawn-sh commands or invalid paths
- Lock screen keybind (MOD+ALT+L) uses swaylock
- Wallpaper keybind (Mod+Shift+W) uses swww with ~/Pictures/walls/
- Audio/brightness keys use swayosd-client
- Startup section only contains working NixOS-compatible commands
- Speech-to-text keybinds commented out with TODO note
</success_criteria>
</content>
</invoke>