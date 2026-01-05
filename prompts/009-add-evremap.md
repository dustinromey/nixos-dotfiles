<objective>
Add evremap (evdev-based key remapper) to the NixOS configuration with a configuration file managed in the config/ folder, following the same symlink pattern used for niri, ghostty, waybar, etc.

evremap runs as a system service (requires root for /dev/input access) and remaps keys at the evdev level, working across both X11 and Wayland.
</objective>

<context>
This is a multi-host NixOS dotfiles repository using flakes with home-manager integration.

Review the existing patterns:
- @./hosts/common/configuration.nix - System-level packages and services
- @./hosts/common/home.nix - Home-manager config with mkOutOfStoreSymlink for configs
- @./config/ - Directory containing application configs that get symlinked to ~/.config/

evremap config files use TOML format and are typically placed at /etc/evremap.toml or specified via command line.
</context>

<requirements>
1. Install evremap package in the system configuration (not home-manager, since it needs root)

2. Create evremap configuration file at `./config/evremap/evremap.toml`:
   - Include commented examples of common remappings
   - Leave the actual remappings minimal/empty for user to customize
   - Document the syntax with inline comments

3. Set up evremap as a systemd service that:
   - Runs at boot
   - Reads config from the appropriate location
   - Has proper permissions for /dev/input access

4. Ensure the config is symlinked appropriately (either via home-manager to ~/.config/evremap/ or directly in NixOS config to /etc/)

5. Add any required udev rules for input device access
</requirements>

<implementation>
Follow the existing patterns in this repository:
- System services go in hosts/common/configuration.nix
- Use lib.mkDefault where appropriate for host-specific overrides
- Config files go in ./config/<app-name>/

For evremap specifically:
- It typically runs as a systemd system service (not user service)
- Config can be at /etc/evremap.toml
- May need `hardware.uinput.enable = true` in NixOS

Example evremap.toml structure:
```toml
# Device selection (optional - matches all if not specified)
# device_name = "AT Translated Set 2 keyboard"

[[remap]]
input = ["KEY_CAPSLOCK"]
output = ["KEY_ESC"]

[[dual_role]]
input = "KEY_CAPSLOCK"
hold = ["KEY_LEFTCTRL"]
tap = ["KEY_ESC"]
```
</implementation>

<output>
Create/modify these files:
- `./config/evremap/evremap.toml` - Configuration file with documented examples
- `./hosts/common/configuration.nix` - Add evremap package and systemd service

Do NOT modify:
- hosts/common/home.nix (evremap is system-level, not user-level)
</output>

<verification>
After implementation:
1. Run `nix flake check` to verify syntax
2. The configuration should be ready for `sudo nixos-rebuild switch --flake .#mischief`
3. After rebuild, verify with:
   - `systemctl status evremap` - Service should be active
   - `cat /etc/evremap.toml` or equivalent - Config should exist
</verification>

<success_criteria>
- evremap package is installed via NixOS configuration
- Configuration file exists at ./config/evremap/evremap.toml with documented syntax
- systemd service is configured to start at boot
- Config file is properly linked/deployed to system location
- nix flake check passes
</success_criteria>
