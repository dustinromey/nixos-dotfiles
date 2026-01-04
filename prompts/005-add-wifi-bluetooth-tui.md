<objective>
Install impala (WiFi TUI) and bluetui (Bluetooth TUI) and integrate them with waybar.

When clicking the WiFi widget, launch impala in a terminal.
When clicking the Bluetooth widget, launch bluetui in a terminal.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

- impala: https://github.com/pythops/impala - TUI for managing WiFi
- bluetui: https://github.com/pythops/bluetui - TUI for managing Bluetooth
- Both are Rust apps available in nixpkgs
- Terminal emulator is ghostty

@home.nix - Add packages here
@config/waybar/config.jsonc - Waybar configuration
@config/waybar/style.css - Waybar styling
</context>

<requirements>
1. Add `impala` and `bluetui` packages to home.nix home.packages
2. Update waybar network module to launch impala on click
3. Add a bluetooth module to waybar between network and battery
4. Configure bluetooth module to launch bluetui on click
5. Style the bluetooth widget to match Tokyo Night theme
</requirements>

<implementation>
Step 1: Add to home.nix home.packages:
```nix
impala
bluetui
```

Step 2: Update config/waybar/config.jsonc:
- Add "on-click": "ghostty -e impala" to the network module
- Add "bluetooth" module to modules-right between network and battery
- Configure bluetooth module with format and on-click

Step 3: Update config/waybar/style.css:
- Add #bluetooth styling matching the existing Tokyo Night theme
</implementation>

<output>
Modify:
- `./home.nix` - Add impala and bluetui packages
- `./config/waybar/config.jsonc` - Add bluetooth module, add on-click handlers
- `./config/waybar/style.css` - Add bluetooth styling
</output>

<verification>
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. In Niri, click on WiFi widget - should open impala in ghostty
3. Click on Bluetooth widget - should open bluetui in ghostty
</verification>

<success_criteria>
- impala and bluetui installed and accessible
- Clicking WiFi widget opens impala in terminal
- Bluetooth widget visible between network and battery
- Clicking Bluetooth widget opens bluetui in terminal
- Styling consistent with Tokyo Night theme
</success_criteria>
