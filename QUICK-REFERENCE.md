# Quick Reference - Multi-Host NixOS

## Rebuild Commands

```bash
# Mischief (ThinkPad X270 - Intel)
sudo nixos-rebuild switch --flake .#mischief

# Intrepid (Desktop - AMD)
sudo nixos-rebuild switch --flake .#intrepid

# Vigilant (Surface Laptop - AMD)
sudo nixos-rebuild switch --flake .#vigilant
```

## Common Operations

```bash
# Validate all host configurations
nix flake check

# Show available hosts
nix flake show

# Format Nix files
nixfmt-rfc-style <file.nix>

# Update flake inputs
nix flake update

# Rebuild home-manager only
home-manager switch --flake .#dustin
```

## File Locations

```
Configuration:
  Common system:     hosts/common/configuration.nix
  Common home:       hosts/common/home.nix
  Host-specific:     hosts/<hostname>/configuration.nix
  Hardware config:   hosts/<hostname>/hardware-configuration.nix

Application configs:
  Shared:            config/
  Per-host override: config-overrides/<hostname>/
```

## Adding a New Host

```bash
# 1. Create host directory
mkdir -p hosts/newhost

# 2. Create configuration (copy from template)
cp hosts/mischief/configuration.nix hosts/newhost/
# Edit hostname and host-specific settings

# 3. Create home configuration
cp hosts/mischief/home.nix hosts/newhost/
# Edit if needed

# 4. Generate hardware config (on target machine)
nixos-generate-config --show-hardware-config > hosts/newhost/hardware-configuration.nix

# 5. Update flake.nix
# Add to nixosConfigurations:
#   newhost = mkHost "newhost" "x86_64-linux";

# 6. Validate
nix flake check
```

## Editing Configurations

```bash
# Edit common system config (affects all hosts)
nvim hosts/common/configuration.nix

# Edit common home config (affects all users)
nvim hosts/common/home.nix

# Edit host-specific system config
nvim hosts/mischief/configuration.nix

# Edit host-specific home config
nvim hosts/mischief/home.nix

# Edit application config (shared across hosts)
nvim config/nvim/init.lua

# Create host-specific override
mkdir -p config-overrides/mischief/nvim
cp config/nvim/init.lua config-overrides/mischief/nvim/
# Edit and update hosts/mischief/home.nix to use override
```

## Troubleshooting

```bash
# Check for syntax errors
nix flake check

# See what would be built (dry run)
nixos-rebuild dry-build --flake .#mischief

# Build without switching
nixos-rebuild build --flake .#mischief

# Show diff before rebuilding
nixos-rebuild dry-activate --flake .#mischief

# View flake info
nix flake metadata

# Check if host config is valid
nix eval .#nixosConfigurations.mischief.config.networking.hostName
```

## Host Specifications

| Host      | Hardware              | CPU/GPU    | RAM   | Notes                    |
|-----------|-----------------------|------------|-------|--------------------------|
| mischief  | ThinkPad X270         | Intel      | ?     | Test machine             |
| intrepid  | Desktop               | AMD/AMD    | 32GB  | Daily driver, AMD GPU    |
| vigilant  | Surface Laptop 4      | AMD/AMD    | 16GB  | AMD GPU, touchpad config |

## Common Settings Modified Per Host

- `networking.hostName` - Always set in host config
- `hardware.graphics.*` - AMD hosts need amdvlk
- `services.libinput.*` - Laptops may need touchpad tweaks
- `boot.initrd.availableKernelModules` - Hardware-dependent
- `hardware.cpu.*.updateMicrocode` - Intel vs AMD
