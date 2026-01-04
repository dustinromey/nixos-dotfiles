# Multi-Host Migration Guide

This document explains the changes made to modularize the NixOS configuration for multiple hosts.

## What Changed

The monolithic configuration has been reorganized into a modular structure supporting three hosts:
- **mischief** (ThinkPad X270, Intel) - test machine
- **intrepid** (Desktop, AMD) - daily driver
- **vigilant** (Surface Laptop 4, AMD)

## Directory Structure Changes

### Before
```
.
├── flake.nix
├── configuration.nix
├── home.nix
├── hardware-configuration.nix
└── config/
```

### After
```
.
├── flake.nix (updated for multi-host)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix (shared NixOS config)
│   │   └── home.nix (shared home-manager config)
│   ├── mischief/
│   │   ├── configuration.nix (host-specific)
│   │   ├── home.nix (host-specific)
│   │   └── hardware-configuration.nix
│   ├── intrepid/
│   │   ├── configuration.nix (AMD GPU config)
│   │   ├── home.nix
│   │   └── hardware-configuration.nix (placeholder)
│   └── vigilant/
│       ├── configuration.nix (AMD GPU + touchpad)
│       ├── home.nix
│       └── hardware-configuration.nix (placeholder)
├── config/ (shared app configs - unchanged)
└── config-overrides/ (optional per-host overrides)
```

## Key Changes

### 1. Flake.nix
- Now uses a `mkHost` helper function to generate configurations
- Defines all three hosts in `nixosConfigurations`
- Each host points to its own `hosts/<hostname>/configuration.nix` and `home.nix`

### 2. Common Configuration
- Shared system config moved to `hosts/common/configuration.nix`
- Shared home config moved to `hosts/common/home.nix`
- Uses `lib.mkDefault` for values that can be overridden by hosts
- Removed hostname-specific settings (now in host configs)

### 3. Host-Specific Configurations
Each host has:
- `configuration.nix`: Imports common config + hardware config, sets hostname, adds host-specific options
- `home.nix`: Imports common home config, can override user settings
- `hardware-configuration.nix`: Hardware detection results or placeholder

### 4. AMD GPU Support
Hosts `intrepid` and `vigilant` include:
```nix
hardware.graphics.enable = true;
hardware.graphics.extraPackages = with pkgs; [ amdvlk ];
```

### 5. Surface-Specific Configuration
Host `vigilant` includes touchpad configuration:
```nix
services.libinput.enable = true;
services.libinput.touchpad = {
  tapping = true;
  naturalScrolling = true;
  disableWhileTyping = true;
};
```

## Rebuilding After Migration

### On mischief (current system)
The rebuild command remains the same:
```bash
sudo nixos-rebuild switch --flake .#mischief
```

### On other hosts
When you set up the other hosts:
```bash
# On intrepid:
sudo nixos-rebuild switch --flake .#intrepid

# On vigilant:
sudo nixos-rebuild switch --flake .#vigilant
```

## Setting Up a New Host

### On the New Machine

1. Clone the repository:
   ```bash
   git clone <repo-url> ~/nixos-dotfiles
   cd ~/nixos-dotfiles
   ```

2. Generate hardware configuration:
   ```bash
   # For intrepid:
   nixos-generate-config --show-hardware-config > hosts/intrepid/hardware-configuration.nix

   # For vigilant:
   nixos-generate-config --show-hardware-config > hosts/vigilant/hardware-configuration.nix
   ```

3. Review and commit the hardware config:
   ```bash
   git add hosts/<hostname>/hardware-configuration.nix
   git commit -m "Add hardware configuration for <hostname>"
   ```

4. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

## Verifying the Configuration

Before committing changes, always run:
```bash
nix flake check
```

This validates all host configurations can build.

## Customizing Per-Host

### System-Level Customization
Edit `hosts/<hostname>/configuration.nix`:
```nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
  ];

  networking.hostName = "<hostname>";

  # Add host-specific options here
  services.xserver.videoDrivers = [ "amdgpu" ];
}
```

### User-Level Customization
Edit `hosts/<hostname>/home.nix`:
```nix
{ config, pkgs, inputs, ... }:
{
  imports = [ ../common/home.nix ];

  # Override packages for this host
  home.packages = with pkgs; [
    # Additional packages...
  ];
}
```

### Application Config Overrides
For host-specific application configs, use `config-overrides/`:
```bash
mkdir -p config-overrides/<hostname>/nvim
# Copy and modify configs...
```

Then update the host's `home.nix` to use the override.

## Rollback Plan

If you need to rollback to the previous structure, the old files are in git history:
```bash
git checkout HEAD~1 -- configuration.nix home.nix hardware-configuration.nix flake.nix
rm -rf hosts/ config-overrides/
```

## Benefits of This Structure

1. **Shared Configuration**: Common settings defined once in `hosts/common/`
2. **Hardware-Specific**: Easy to add AMD GPU, touchpad, or other hardware features
3. **Maintainable**: Changes to common config automatically apply to all hosts
4. **Flexible**: Each host can override any setting from common config
5. **Scalable**: Adding new hosts is straightforward and follows a clear pattern
6. **Type-Safe**: Nix ensures all configurations are valid before building
